// /* eslint-disable no-undef */
const assert = require('chai').assert // use Chai Assertion Library
// const ganache = require('ganache-cli') // use ganache-cli with ethereum-bridge for Oraclize

// // Configure web3 1.0.0 instead of the default version with Truffle
// const Web3 = require('web3')
// const provider = ganache.provider()

const Dice = artifacts.require("Dice");

const helpers = {

    checkWinner: (player1, player2) => {
        if ((player1.choice + 1) % 3 == player2.choice) {
            return player2.address;
        }
        else if ((player1.choice + 2) % 3 == player2.choice) {
            return player1.address;
        }
        else {
            return 0;
        }
    },

    sleep: (ms) => {
        return new Promise(resolve => setTimeout(resolve, ms));
      }
}

contract("Dice", async (accounts) => {

    before(async () => {
        owner = accounts[0];
    });

    beforeEach(async () => {
        player1 = {
            address: accounts[1],
            choice: 50
        }

        player2 = {
            address: accounts[2],
            // choice: PAPER
        }

        dice = await Dice.deployed();
    });

    it("Test fund game", async () => {

        // Initial fund must be 0
        initialJackpot = await dice.jackpot({from: accounts[1]});
        assert.equal(initialJackpot, 0);

        // Fund game with several contributions
        const fund0 = web3.utils.toWei('0.021');
        const fund1 = web3.utils.toWei('0.12');
        const fund2 = web3.utils.toWei('0.13');
        const fund3 = web3.utils.toWei('0.35');
        const totalFund = parseInt(fund0) + parseInt(fund1) + parseInt(fund2) + parseInt(fund3);

        dice.fundGame({from: accounts[0], value: fund0});
        dice.fundGame({from: accounts[1], value: fund1});
        dice.fundGame({from: accounts[2], value: fund2});
        dice.fundGame({from: accounts[0], value: fund3});

        currentJackpot = parseInt(await dice.jackpot({from: accounts[0]}));

        assert.equal(currentJackpot, totalFund, 'Current jackpot not as expected');
    });

    it("Test start game", async () => {

        // Game is not started auto
        assert.isFalse(await dice.gameRunning(), 'Game should not be running');

        // Previous fund was below minimum jackpot, then game could not be started
        try {
            await dice.startGame({from: owner});
        }
        catch(e) {}
        assert.isFalse(await dice.gameRunning(), 'Game should not be running');
        assert.isFalse(await dice.lotteryOn(), 'Lottery should not be on');

        // Not possible to start game if not owner
        try {
            await dice.startGame({from: accounts[1]});
        }
        catch(e) {
            assert.isFalse(await dice.gameRunning(), 'Game should not be running');

            // Start game after funding it
            dice.fundGame({from: accounts[1], value: await dice.minJackpot()});
            await dice.startGame({from: owner});
            assert.isTrue(await dice.gameRunning(), 'Game should be running');
            assert.isTrue(await dice.lotteryOn(), 'Lottery should be on');

            return;
        }

        assert.isOk(false, 'Game started from non owner');  // It shouldn't reach this assert
    });

    it("Test stop game", async () => {

        // Game is started from previous tests
        assert.isTrue(await dice.gameRunning(), 'Game should be running');

        // Not possible to stop game if not owner
        try {
            await dice.stopGame({from: accounts[1]});
        }
        catch(e) {
            assert.isTrue(await dice.gameRunning(), 'Game should be running');

            // Owner can stop game
            dice.stopGame({from: owner});
            assert.isFalse(await dice.gameRunning(), 'Game should not be running');
            assert.isFalse(await dice.lotteryOn(), 'Lottery should not be on');

            return;
        }

        assert.isOk(false, 'Game stopped from non owner');  // It shouldn't reach this assert
    });


    it("Rolling magic dice", async () => {

        // Make sure the game is on
        try {
            await dice.startGame({from: owner});
        }
        catch(e){}

        const house = {
            address: dice.address,
        }
        await dice.fundGame({from: accounts[1], value: web3.utils.toWei('5')});
        const roundsNumber = 1;
        const betAmount = web3.utils.toWei('1');
        var expectedPlayersBalance;
        var expectedContractsBalance;

        // Percentage constant for fees. Copied from sol contract
        const jackpotFeeRate = 0.005;
        const jackpotFees = jackpotFeeRate * parseInt(betAmount);
        const businessFeeRate = 2 * await dice.lotteryRate() / 1000000;
        const businessFees = businessFeeRate * parseInt(betAmount);

        // Disable lottery in order to calculate new balances without jackpot effect
        dice.stopLottery({from: owner});

        for (i of [...Array(roundsNumber).keys()]) {
            const previousPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));
            const previousContractsBalance = parseInt(await web3.eth.getBalance(dice.address));

            // Pick a random number to test between 30-80 (valid risk numbers)
            player1.choice = Math.floor((Math.random() * 50) + 31);;
            await dice.playSoloRound(player1.choice, {from: player1.address, value: betAmount});

            const lastRound = await dice.roundCount();

            await helpers.sleep(80000);

            const roundInfo =  await dice.getRoundInfo(lastRound);
            const result = parseInt(roundInfo.rolledDiceNumber);

            assert.isAtLeast(result, 1, 'Random number was less than 1');
            assert.isAtMost(result, 100, 'Random number was greater than 100');

            const newPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));
            const newContractsBalance = parseInt(await web3.eth.getBalance(dice.address));
            const gasFees =  parseInt(web3.utils.toWei('0.05'));  // Gas fees, adjust when we know better about gas cost
            const oraclizeFees = parseInt(web3.utils.toWei('0.04'));
            const profit = parseInt(betAmount) * (100 / (100 - player1.choice));

            if (result > player1.choice) {
                // Player wins
                expectedPlayersBalance = previousPlayersBalance + profit - parseInt(betAmount) - jackpotFees - businessFees;
                expectedContractsBalance = previousContractsBalance - profit + parseInt(betAmount) + jackpotFees + businessFees;
                expectedWinner = player1.address;
            } else {
                // Player loses
                expectedPlayersBalance = previousPlayersBalance - parseInt(betAmount) - jackpotFees - businessFees;
                expectedContractsBalance = previousContractsBalance + parseInt(betAmount);
                expectedWinner = dice.address;
            }

            assert.equal(roundInfo.winner, expectedWinner, 'Winner not as expected');
            assert.closeTo(parseInt(newPlayersBalance), expectedPlayersBalance, gasFees, 'Player balance is wrong after round');
            assert.closeTo(newContractsBalance, expectedContractsBalance, gasFees, 'House balance is wrong after round');
        }

        // dice.startLottery({from: owner});

    });

     // This test is disabled because it takes too long (because of oraclize) to play several rounds until a round
    // wins the lottery, and the test fails because of an internal timeout.
    // This was tested without oraclize, getting random numbers internally, and it passed.
    xit("Test play lottery)", async () => {

        // Make sure the game is on
        try {
            await dice.startGame({from: owner});
        }
        catch(e){}

        dice.startLottery({from: owner});

        await dice.fundGame({from: accounts[0], value: web3.utils.toWei('4')});

        // I can set a new lottery rate
        const newLotteryRate = 4;
        await dice.setLotteryRate(newLotteryRate);
        assert.equal(newLotteryRate, await dice.lotteryRate());

        const roundsNumber = 50;
        const betAmount = web3.utils.toWei('0.05');

        let lotteryWinner;
        let jackpot;
        let previousPlayersBalance;

        initialContractBalance = parseInt(await web3.eth.getBalance(dice.address));
        initialJackpot = parseInt(await dice.jackpot());
        // The idea is to modify the number of rounds and chance of winning to assure that there is a big change of winning
        // lottery, so we can get an event of winning lottery.
        for (i of [...Array(roundsNumber).keys()]) {
            previousPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));
            jackpot = parseInt(await dice.jackpot());

            let lastRound = parseInt(await dice.roundCount());
            result = await dice.playSoloRound(player1.choice, {from: player1.address, value: betAmount});
            do{
                roundInfo =  await dice.getRoundInfo(lastRound + 1);
                await helpers.sleep(90000);
            } while (!roundInfo.isClosed);

            roundInfo =  await dice.getRoundInfo(lastRound + 1);

            if (roundInfo.lotteryWinner != "0x0000000000000000000000000000000000000000"){
                lotteryWinner = roundInfo.lotteryWinner;
                break;
            }
        }

        const probalityOfWinning = 1 - ((newLotteryRate - 1) / newLotteryRate) ** roundsNumber;

        assert.isOk(lotteryWinner, "Probabilistic, there should exist a winner (" + probalityOfWinning * 100 + "%)");

        const fees =  parseInt(web3.utils.toWei('0.09'));  // Gas fees, adjust when we know better about gas cost
        const newLotteryWinnerBalance = parseInt(await web3.eth.getBalance(lotteryWinner));
        const expectedLotteryWinnerBalance = previousPlayersBalance + jackpot;
        const contractsBalance = parseInt(await web3.eth.getBalance(dice.address));
        assert.closeTo(expectedLotteryWinnerBalance, newLotteryWinnerBalance, fees, 'Lottery winner balance is wrong');
        assert.closeTo(initialContractBalance - initialJackpot, contractsBalance, parseInt(betAmount) * 2, 'Contract balance should be minus jackpot');
    });
}
)