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

        currentJackpot = (await rps.jackpot({from: accounts[0]})).toString();

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

    it("Test cancel round", async () => {

        const betAmount = web3.utils.toWei('0.11');

        // Percentage constant for fees. Copied from sol contract
        const jackpotFeeRate = 0.005;
        const jackpotFees = jackpotFeeRate * parseInt(betAmount);
        const businessFeeRate = 2 * await rps.lotteryRate() / 1000000;
        const businessFees = businessFeeRate * parseInt(betAmount);

        const gasFees =  parseInt(web3.utils.toWei('0.05'));  // Gas fees, adjust when we know better about gas cost

        var previousPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));

        await rps.createRound(web3.utils.soliditySha3(player1.choice, SECRET), {from: player1.address, value: betAmount})
        lastRound = await rps.roundCount();

        await rps.cancelRound(lastRound, {from: player1.address});

        roundInfo = await rps.getRoundInfo(lastRound);
        var newPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));

        assert.isFalse(roundInfo[6]);
        assert.closeTo(newPlayersBalance,  previousPlayersBalance - jackpotFees - businessFees, gasFees,
            "Player's balance should be previous balance minus fees");


        previousPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));
        await rps.createRound(web3.utils.soliditySha3(player1.choice, SECRET), {from: player1.address, value: betAmount})
        lastRound = await rps.roundCount();

        await rps.cancelRound(lastRound, player1.choice, SECRET);

        roundInfo = await rps.getRoundInfo(lastRound);
        newPlayersBalance = parseInt(await web3.eth.getBalance(player1.address));

        assert.isFalse(roundInfo[6]);
        assert.closeTo(newPlayersBalance, previousPlayersBalance - jackpotFees - businessFees , gasFees,
            "Player's balance should be previous balance minus fees");

    });

}
)
