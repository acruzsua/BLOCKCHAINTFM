const ROCK = 0;
const PAPER = 1;
const SCISSORS = 2;

const SECRET = "secret";

const RPS = artifacts.require("RPS");


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


contract("RPS", async (accounts) => {

    before(async () => {
        owner = accounts[0];
    });

    beforeEach(async () => {
        player1 = {
            address: accounts[1],
            choice: ROCK
        }

        player2 = {
            address: accounts[2],
            choice: PAPER
        }

        rps = await RPS.deployed();
    });

    it("Test fund game", async () => {

        // Initial fund must be 0
        initialJackpot = await rps.jackpot({from: accounts[1]});
        assert.equal(initialJackpot, 0);

        // Fund game with several contributions
        const fund0 = web3.utils.toWei('0.021');
        const fund1 = web3.utils.toWei('0.12');
        const fund2 = web3.utils.toWei('0.13');
        const fund3 = web3.utils.toWei('0.35');
        const totalFund = parseInt(fund0) + parseInt(fund1) + parseInt(fund2) + parseInt(fund3);

        rps.fundGame({from: accounts[0], value: fund0});
        rps.fundGame({from: accounts[1], value: fund1});
        rps.fundGame({from: accounts[2], value: fund2});
        rps.fundGame({from: accounts[0], value: fund3});

        currentJackpot = parseInt(await rps.jackpot({from: accounts[0]}));

        assert.equal(currentJackpot, totalFund, 'Current jackpot not as expected');
    });

    it("Test start game", async () => {

        // Game is not started auto
        assert.isFalse(await rps.gameRunning(), 'Game should not be running');

        // Previous fund was below minimum jackpot, then game could not be started
        try {
            await rps.startGame({from: owner});
        }
        catch(e) {}
        assert.isFalse(await rps.gameRunning(), 'Game should not be running');
        assert.isFalse(await rps.lotteryOn(), 'Lottery should not be on');

        // Not possible to start game if not owner
        try {
            await rps.startGame({from: accounts[1]});
        }
        catch(e) {
            assert.isFalse(await rps.gameRunning(), 'Game should not be running');

            // Start game after funding it
            rps.fundGame({from: accounts[3], value: await rps.minJackpot()});
            await rps.startGame({from: owner});
            assert.isTrue(await rps.gameRunning(), 'Game should be running');
            assert.isTrue(await rps.lotteryOn(), 'Lottery should be on');

            return;
        }

        assert.isOk(false, 'Game started from non owner');  // It shouldn't reach this assert
    });

    it("Test stop game", async () => {

        // Game is started from previous tests
        assert.isTrue(await rps.gameRunning(), 'Game should be running');

        // Not possible to stop game if not owner
        try {
            await rps.stopGame({from: accounts[1]});
        }
        catch(e) {
            assert.isTrue(await rps.gameRunning(), 'Game should be running');

            // Owner can stop game
            rps.stopGame({from: owner});
            assert.isFalse(await rps.gameRunning(), 'Game should not be running');
            assert.isFalse(await rps.lotteryOn(), 'Lottery should not be on');

            return;
        }

        assert.isOk(false, 'Game stopped from non owner');  // It shouldn't reach this assert
    });

    it("Playing vs the House", async () => {

        // Make sure the game is on
        try {
            rps.fundGame({from: accounts[3], value: await rps.minJackpot()});
            await rps.startGame({from: owner});
        }
        catch(e){}

        const house = {
            address: rps.address,
        }

        const roundsNumber = 1;
        const betAmount = web3.utils.toWei('0.1');
        let expectedPlayersBalance;
        let expectedContractsBalance;

        // Percentage constant for fees. Copied from sol contract
        const jackpotFeeRate = 0.005;
        const jackpotFees = jackpotFeeRate * parseInt(betAmount);
        const businessFeeRate = 2 * await rps.lotteryRate() / 1000000;
        const businessFees = businessFeeRate * parseInt(betAmount);
        const oraclizeFees = parseInt(web3.utils.toWei('0.04'));

        // Disable lottery in order to calculate new balances without jackpot effect
        rps.stopLottery({from: owner});

        // Try several attemps to assure that passing the test is not because of a random gess.
        // Maybe final version redouce the attemps to get lower unit test time.
        for (i of [...Array(roundsNumber).keys()]) {
            const previousPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));
            const previousContractsBalance = parseInt(await web3.eth.getBalance(rps.address));
            player1.choice = i % 3;  // to select different player choices
            rps.playSoloRound(player1.choice, {from: player1.address, value: betAmount});
            let lastRound = await rps.roundCount();
            await helpers.sleep(60000);
            roundInfo =  await rps.getRoundInfo(lastRound);

            house.choice = roundInfo[3].toString();
            winner = roundInfo[5];

            const expectedWinner = helpers.checkWinner(player1, house);

            assert.equal(expectedWinner, winner, "Winner not as expected");

            const newPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));
            const newContractsBalance = parseInt(await web3.eth.getBalance(rps.address));
            const gasFees =  parseInt(web3.utils.toWei('0.05'));  // Gas fees, adjust when we know better about gas cost

            if (winner == player1.address) {
                expectedPlayersBalance = previousPlayersBalance + parseInt(betAmount) - jackpotFees - businessFees;
                expectedContractsBalance = previousContractsBalance - parseInt(betAmount) + jackpotFees + businessFees;
            } else if (winner == RPS.address) {
                expectedPlayersBalance = previousPlayersBalance -  parseInt(betAmount);
                expectedContractsBalance = previousContractsBalance + parseInt(betAmount) - oraclizeFees;
            } else {
                expectedPlayersBalance = previousPlayersBalance - jackpotFees - businessFees;
                expectedContractsBalance = previousContractsBalance + jackpotFees + businessFees - oraclizeFees;
            }

            assert.closeTo(newPlayersBalance, expectedPlayersBalance, gasFees, 'Player balance is wrong after round vs House');
            assert.closeTo(newContractsBalance, expectedContractsBalance, gasFees, 'House balance is wrong after round vs House');
        }

        //rps.startLottery({from: owner});
    });

    it("Test getting info from round (vs House)", async () => {

        try {
            await rps.startGame({from: owner});
        }
        catch(e){}

        const betAmount = web3.utils.toWei('0.11');

        rps.playSoloRound(player1.choice, {from: player1.address, value: betAmount});

        let lastRound = await rps.roundCount();
        roundInfo =  await rps.getRoundInfo(lastRound);

        assert.equal(player1.address, roundInfo[0], 'Player1 address wrong');
        assert.equal(player1.choice, roundInfo[1], 'Player1 choice wrong');
        assert.equal(rps.address, roundInfo[2], 'House address wrong');
        assert.isTrue(roundInfo[3] in [ROCK, PAPER, SCISSORS], 'House choice wrong');  // We can't know the house choice, just check is one of three
        assert.equal(betAmount, roundInfo[4], 'House address wrong');
    });

    it("Playing 2 players", async () => {

        rps.stopLottery({from: owner});
        const betAmount = web3.utils.toWei('0.1');

        // Percentage constant for fees.
        const jackpotFeeRate = 0.005;
        const jackpotFees = jackpotFeeRate * parseInt(betAmount);
        const businessFeeRate = 2 * await rps.lotteryRate() / 1000000;
        const businessFees = businessFeeRate * parseInt(betAmount);

        // Try several attemps to assure that passing the test is not because of a random gess.
        // Maybe final version reduce the attemps to get lower unit test time.
        // We don't care the secret word for this test, so try with "SECRET"
        for (i of [...Array(3).keys()]) {
            const previousPlayer1sBalance = parseInt(await web3.eth.getBalance(player1.address));
            const previousPlayer2sBalance = parseInt(await web3.eth.getBalance(player2.address));
            const previousContractsBalance = parseInt(await web3.eth.getBalance(rps.address));

            player2.choice = i % 3;  // to select different player choices
            rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: betAmount});
            let lastRound = await rps.roundCount();
            rps.joinSecretRound(lastRound, player2.choice, {from: player2.address, value: betAmount});
            await rps.revealChoice(lastRound, player1.choice, SECRET, {from: player1.address});
            roundInfo =  await rps.getRoundInfo(lastRound);

            isClose = roundInfo[6];
            assert.isTrue(isClose, "Round not finished after revealing");

            winner = roundInfo[5];
            const expectedWinner = helpers.checkWinner(player1, player2);
            assert.equal(expectedWinner, winner, "Winner not as expected");

            const newPlayer1sBalance = parseInt(await web3.eth.getBalance(player1.address));
            const newPlayer2sBalance = parseInt(await web3.eth.getBalance(player2.address));
            const gasFees =  parseInt(web3.utils.toWei('0.05'));  // Gas fees, adjust when we know better about gas cost

            const newContractsBalance = parseInt(await web3.eth.getBalance(rps.address));

            if (winner == player1.address) {
                expectedPlayer1sBalance = previousPlayer1sBalance + parseInt(betAmount) - jackpotFees - businessFees;
                expectedPlayer2sBalance = previousPlayer2sBalance - parseInt(betAmount);
                expectedContractsBalance = previousContractsBalance + jackpotFees + businessFees;
            } else if (winner == player2.address) {
                expectedPlayer1sBalance = previousPlayer1sBalance - parseInt(betAmount);
                expectedPlayer2sBalance = previousPlayer2sBalance + parseInt(betAmount) - jackpotFees - businessFees;
                expectedContractsBalance = previousContractsBalance + jackpotFees + businessFees;
            } else {
                expectedPlayer1sBalance = previousPlayer1sBalance - jackpotFees - businessFees / 2;
                expectedPlayer2sBalance = previousPlayer2sBalance - jackpotFees - businessFees / 2;
                expectedContractsBalance = previousContractsBalance + 2* jackpotFees + businessFees;
            }

            assert.closeTo(newPlayer1sBalance, expectedPlayer1sBalance, gasFees, 'Player1 balance is wrong after round vs Player2');
            assert.closeTo(newPlayer2sBalance, expectedPlayer2sBalance, gasFees, 'Player2 balance is wrong after round vs Player2');
            assert.equal(newContractsBalance, expectedContractsBalance, 'House balance is wrong after round vs House');
        }

        rps.startLottery({from: owner});
    });

    it("Test getting info from round (2 players)", async () => {

        const betAmount = web3.utils.toWei('0.11');

        await rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: betAmount});

        let lastRound = await rps.roundCount();
        await rps.joinSecretRound(lastRound, player2.choice, {from: player2.address, value: betAmount});
        await rps.revealChoice(lastRound, player1.choice, SECRET, {from: player1.address});
        const roundInfo = await rps.getRoundInfo(lastRound);
        assert.equal(player1.address, roundInfo[0], 'Player1 address wrong');
        assert.equal(player1.choice, roundInfo[1], 'Player1 choice wrong');
        assert.equal(player2.address, roundInfo[2], 'Player2 address wrong');
        assert.equal(player2.choice, roundInfo[3], 'Player2 choice wrong');
        assert.equal(betAmount, roundInfo[4], 'House address wrong');
        winner = roundInfo[5];
        assert.equal(player2.address, roundInfo[5], 'Winner wrong');  // Paper beats rock, player2 must win
    });

    // Disabled because no idea why this fails sometimes and makes other test fail too
    it("Test paying business fee", async () => {
        try {
            await rps.startGame({from: owner});
        }
        catch(e){}

        const house = {
            address: rps.address,
        }

        const roundsNumber = 2;
        const betAmount = web3.utils.toWei('0.1');

        // Percentage constant for fees. Copied from sol contract
        // const jackpotFeeRate = 0.005;
        const businessFeeRate = 2 * await rps.lotteryRate() / 1000000;
        const businessFees = businessFeeRate * parseInt(betAmount);
        const businessAddress = await rps.businessAddress();
        const initialBusinessBalance = parseInt(await web3.eth.getBalance(businessAddress));
        const initialTotalBusinessFee = parseInt(await rps.totalBusinessFee());

        // Setting minimum business fee transfer to check that money is actually transfered
        const initialMinBusinessFeePayment = await rps.minBusinessFeePayment();
        await rps.setminBusinessFeePayment(1, {from: owner});

        const gasFees = parseInt(web3.utils.toWei('0.002'));

        for (i of [...Array(roundsNumber).keys()]) {
            player1.choice = i % 3;  // to select different player choices
            await rps.playSoloRound(player1.choice, {from: player1.address, value: betAmount});
            await helpers.sleep(50000);
        }
        const businessBalance = parseInt(await web3.eth.getBalance(businessAddress));
        assert.closeTo(businessBalance, initialTotalBusinessFee + initialBusinessBalance  + roundsNumber * businessFees, gasFees, 'Business fess not collected correctly');
        await rps.setminBusinessFeePayment(initialMinBusinessFeePayment, {from: owner});
    });

    it("Test error when creating round with bet lower than minimum bet", async () => {

        const minimumBet = await rps.minimumBet();
        const lastRound = await rps.roundCount();

        try {
            await rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: minimumBet - 1});
        }
        catch(e) {
            const newLastRound = await rps.roundCount();
            assert.equal(parseInt(lastRound), newLastRound, 'New round should not be created');
            // But we can create new round with minimum bet
            await rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: minimumBet});
            return;
        }

        assert.isOk(false, 'Round should not be possible to be created');  // It shouldn't reach this assert
    });

    it("Test error when joining to a non existing round", async () => {

        const betAmount = web3.utils.toWei('0.11');

        // await rps.createRound(true, player1.choice, {from: player1.address, value: betAmount})
        let lastRound = await rps.roundCount();

        const roundToJoin = lastRound + 100
        try {
            await rps.joinSecretRound(roundToJoin, player2.choice, {from: player2.address, value: betAmount})
        }
        catch(e) {
            roundInfo = await rps.getRoundInfo(roundToJoin);
            assert.equal(0, roundInfo[0], 'Player1 should be 0');
            assert.equal(0, roundInfo[2], 'Player2 should be 0');
            assert.equal(0, roundInfo[4], 'Bet amount should be 0');
            assert.equal(0, roundInfo[5], 'Winner should be 0');
            return;
        }

        assert.isOk(false, 'It should not be possibe to join to a non existing round');  // It shouldn't reach this assert
    });


    it("Test error when joining to a finished 1 player round", async () => {

        const betAmount = web3.utils.toWei('0.11');

        await rps.playSoloRound(player1.choice, {from: player1.address, value: betAmount})
        let lastRound = await rps.roundCount();

        // Player2 cannot join to this round becaouse it is finished
        try {
            await rps.joinSecretRound(lastRound, player2.choice, {from: player2.address, value: betAmount})
        }
        catch(e) {
            roundInfo = await rps.getRoundInfo(lastRound);
            assert.equal(rps.address, roundInfo[2], 'Player 2 address should be player2.address');
            return;
        }

        assert.isOk(false, 'It should not be possibe to join to a non existing round');  // It shouldn't reach this assert
    });

    it("Test error when joining to a finished 2 players round", async () => {

        const player3 = {
            address: accounts[3],
            choice: PAPER
        }

        const betAmount = web3.utils.toWei('0.11');

        await rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: betAmount})
        lastRound = await rps.roundCount();

        // Player2 can join last round and then it finishes
        await rps.joinSecretRound(lastRound, player2.choice, {from: player2.address, value: betAmount})

        // Player3 cannot join to this round becaouse it is finished
        try {
            await rps.joinSecretRound(lastRound, player3.choice, {from: player3.address, value: betAmount})
        }
        catch(e) {
            roundInfo = await rps.getRoundInfo(lastRound);
            assert.equal(player2.address, roundInfo[2], 'Player 2 address should be player2.address');
            return;
        }

        assert.isOk(false, 'It should not be possibe to join to a finished 2 players round');  // It shouldn't reach this assert
    });

    it("Test error when joining to a round sending lower bet amount", async () => {

        const betAmount = web3.utils.toWei('0.11');

        await rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: betAmount})
        const lastRound = await rps.roundCount();

        try {
            // Not possible to test boundary values since it seems it accepts a bet with a lower up to 8 wei bet
            // For me it's a really weird thing, I guess it's Ethereum-EVM-Solidity stuff.
            await rps.joinSecretRound(lastRound, player2.choice, {from: player2.address, value: betAmount - 10})
        }
        catch(e) {
            roundInfo = await rps.getRoundInfo(lastRound);
            assert.equal(0, roundInfo[2], 'Player2 should be 0');
            assert.equal(betAmount, roundInfo[4], 'Bet amount should be 0');
            assert.equal(0, roundInfo[5], 'Winner should be 0');
            return;
        }

        assert.isOk(false, 'It should not be possibe to join to a round with lower bet');  // It shouldn't reach this assert
    });

    it("Test error withdrawing when game is running", async () => {

        // Game is running
        assert.isTrue(await rps.gameRunning(), 'Game should be running');

        const initialOwnerBalance = parseInt(await web3.eth.getBalance(owner));
        const initialContractBalance = parseInt(await web3.eth.getBalance(rps.address));

        const fees =  parseInt(web3.utils.toWei('0.05'));  // Gas fees, adjust when we know better about gas cost

        try {
            await rps.withdrawFunds(owner, {from: owner});
        }
        catch(e) {
            assert.closeTo(initialOwnerBalance, parseInt(await web3.eth.getBalance(owner)), fees,
             'Owner balance should be the same');

            assert.equal(initialContractBalance, parseInt(await web3.eth.getBalance(rps.address)),
             'Contract balance should be the same');

            return;
        }

        assert.isOk(false, 'Unauthorized withdraw when game is running');  // It shouldn't reach this assert
    });

    it("Test error revealing round when nobody has joined", async () => {

        const betAmount = web3.utils.toWei('0.1');

        rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: betAmount});
        let lastRound = await rps.roundCount();

        // Not possible to reveal because nobody joined to the round
        try {
            await rps.revealChoice(lastRound, player1.choice, SECRET, {from: player1.address});
        }
        catch(e) {
            roundInfo =  await rps.getRoundInfo(lastRound);
            isClose = roundInfo[6];
            assert.isFalse(isClose, "Round finished when revealing with wrong secret");
            return;
        }
        assert.isOk(false, 'Unauthorized reveal3');  // It shouldn't reach this assert
    });

    it("Test error revealing round because of wrong secret", async () => {

        const betAmount = web3.utils.toWei('0.1');

        rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: betAmount});
        let lastRound = await rps.roundCount();

        rps.joinSecretRound(lastRound, player2.choice, {from: player2.address, value: betAmount});

        // Not possible to reveal because of wrong secret
        try {
            await rps.revealChoice(lastRound, player1.choice, "WRONG_SECRET", {from: player1.address});
        }
        catch(e) {
            roundInfo =  await rps.getRoundInfo(lastRound);
            isClose = roundInfo[6];
            assert.isFalse(isClose, "Round finished when revealing with wrong secret");
            return;
        }
        assert.isOk(false, 'Unauthorized reveal3');  // It shouldn't reach this assert
    });

    it("Test error revealing round after revealing wrong choice", async () => {

        const betAmount = web3.utils.toWei('0.1');

        rps.createSecretRound(web3.utils.soliditySha3(SECRET, player1.choice), {from: player1.address, value: betAmount});
        let lastRound = await rps.roundCount();

        // Not possible to reveal because player provides wrong choice
        try {
            await rps.revealChoice(lastRound, player1.choice + 1, SECRET, {from: player1.address});
        }
        catch(e) {
            roundInfo =  await rps.getRoundInfo(lastRound);
            isClose = roundInfo[6];
            assert.isFalse(isClose, "Round finished when revealing with wrong secret");
            return;
        }
        assert.isOk(false, 'Unauthorized reveal3');  // It shouldn't reach this assert
    });

    // This test is disabled because it takes too long (because of oraclize) to play several rounds until a round
    // wins the lottery, and the test fails because of an internal timeout.
    // This was tested without oraclize, getting random numbers internally, and it passed.
    it("Test play lottery (playing vs House)", async () => {

        // Make sure the game is on
        try {
            await rps.startGame({from: owner});
        }
        catch(e){}

        rps.startLottery({from: owner});

        await rps.fundGame({from: accounts[0], value: web3.utils.toWei('2')});

        // I can set a new lottery rate
        const newLotteryRate = 4;
        await rps.setLotteryRate(newLotteryRate);
        assert.equal(newLotteryRate, await rps.lotteryRate());

        const roundsNumber = 50;
        const betAmount = web3.utils.toWei('0.05');

        let lotteryWinner;
        let jackpot;
        let previousPlayersBalance;

        initialContractBalance = parseInt(await web3.eth.getBalance(rps.address));
        initialJackpot = parseInt(await rps.jackpot());
        // The idea is to modify the number of rounds and chance of winning to assure that there is a big change of winning
        // lottery, so we can get an event of winning lottery.
        for (i of [...Array(roundsNumber).keys()]) {
            previousPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));
            jackpot = parseInt(await rps.jackpot());

            let lastRound = parseInt(await rps.roundCount());
            result = await rps.playSoloRound(player1.choice, {from: player1.address, value: betAmount});
            do{
                roundInfo =  await rps.getRoundInfo(lastRound + 1);
                await helpers.sleep(80000);
            } while (!roundInfo.isClosed);

            roundInfo =  await rps.getRoundInfo(lastRound + 1);

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
        const contractsBalance = parseInt(await web3.eth.getBalance(rps.address));
        assert.closeTo(expectedLotteryWinnerBalance, newLotteryWinnerBalance, fees, 'Lottery winner balance is wrong');
        assert.closeTo(initialContractBalance - initialJackpot, contractsBalance, parseInt(betAmount) * 2, 'Contract balance should be minus jackpot');
    });


    it("Test error withdrawing funds when not owner", async () => {

        // Stop game is necessary
        await rps.stopGame({from: owner});

        const unauthorizeUser = accounts[1];
        const initialUserBalance = parseInt(await web3.eth.getBalance(unauthorizeUser));
        const initialContractBalance = parseInt(await web3.eth.getBalance(rps.address));

        const fees =  parseInt(web3.utils.toWei('0.05'));  // Gas fees, adjust when we know better about gas cost

        try {
            await rps.withdrawFunds(unauthorizeUser, {from: unauthorizeUser});
        }
        catch(e) {
            assert.closeTo(initialUserBalance, parseInt(await web3.eth.getBalance(unauthorizeUser)), fees,
             'Unauthorized user balance should be the same');

            assert.equal(initialContractBalance, parseInt(await web3.eth.getBalance(rps.address)),
             'Contract balance should be the same');

            return;
        }

        assert.isOk(false, 'Unauthorized withdraw from non owner');  // It shouldn't reach this assert
    });

    it("Test withdraw funds", async () => {

        withdrawalAddress = accounts[2];
        const initialUserBalance = parseInt(await web3.eth.getBalance(withdrawalAddress));
        const initialContractBalance = parseInt(await web3.eth.getBalance(rps.address));

        const fees =  parseInt(web3.utils.toWei('0.05'));  // Gas fees, adjust when we know better about gas cost

        await rps.withdrawFunds(withdrawalAddress, {from: owner});

        assert.closeTo(initialUserBalance + initialContractBalance, parseInt(await web3.eth.getBalance(withdrawalAddress)), fees,
            'Owner user balance should be previous balance + contract balance');

        assert.equal(0, parseInt(await web3.eth.getBalance(rps.address)),
            'Contract balance should be 0');

    });

}
)
