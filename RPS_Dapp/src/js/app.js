App = {

  web3Provider: null,
  contracts: {},

  init: () =>  {
    return App.initWeb3();
  },

  initWeb3: () => {
    // Is there an injected web3 instance?
    if (typeof web3 !== 'undefined') {
      App.web3Provider = web3.currentProvider;
    } else {
      // If no injected web3 instance is detected, fall back to Ganache
      App.web3Provider = new Web3.providers.HttpProvider('http://localhost:8545');
    }
    web3 = new Web3(App.web3Provider);
    return App.initContract();
  },

  initContract: () => {
    $.getJSON('Dice.json', data => {
      // Get the necessary contract artifact file and instantiate it with truffle-contract
      const DiceArtifact = data;
      App.contracts.Dice = TruffleContract(DiceArtifact);

      // Set the provider for our contract
      App.contracts.Dice.setProvider(App.web3Provider);
      
    });

    return App.bindEvents();
  },

  bindEvents: () => {
    $(document).on('click', '.btn-to-dice', function(event){
      self.location='./indexdice.html';
    });
    $(document).on('click', '.btn-dice', function(event){
      App.roll();
    });


  },

  roll: async () => {

     const betAmount = web3.toWei($('#betAmount').val(), 'ether');
     const risk = ($('#risk').val());

     console.log(betAmount);
     console.log(risk);

     const diceInstance = await App.contracts.Dice.deployed();

     web3.eth.getAccounts(async (error, accounts) => {
     const account = await accounts[0];
     const result = await diceInstance.rollDice(risk, {from: account, value: betAmount});

       
     var LogPlayerBetAccepted = diceInstance.logPlayerBetAccepted({});
     LogPlayerBetAccepted.watch(function (err, result) {
       if (!err) {
        console.log("bet accepted");
        console.log((result.args._bet).valueOf());
        console.log("risk");
        console.log((result.args._risk).valueOf());

      } else {
         console.error(err);
       }
     })

     var LogRolledDice = diceInstance.logRollDice({});
     LogRolledDice.watch(function (err, result) {
       if (!err) {
        console.log((result.args._description).valueOf());

      } else {
         console.error(err);
       }
     })

     var LogRolledDiceNumber = diceInstance.logRolledDiceNumber({});
     LogRolledDiceNumber.watch(function (err, result) {
       if (!err) {
        console.log("getting number");
        console.log((result.args._rolledDiceNumber).valueOf());
       } else {
         console.error(err);
       }
     })

     var LogPlayerWins = diceInstance.logPlayerWins({});
     LogPlayerWins.watch(function (err, result) {
       if (!err) {
        console.log((result.args.description).valueOf());
        console.log((result.args._contract).valueOf());
        console.log((result.args._winner).valueOf());
        console.log((result.args._rolledDiceNumber).valueOf());
        console.log((result.args._profit).valueOf());
        console.log((result.args._riskPer).valueOf());
        console.log((result.args._grossP).valueOf());
        
       } else {
         console.error(err);
       }
     })

      var LogJackpotBalance = diceInstance.logJackpotBalance({});
      LogJackpotBalance.watch(function (err, result) {
        if (!err) {
          console.log((result.args.description).valueOf());
          console.log((result.args._ownerAddress).valueOf());
          console.log((result.args._ownerBalance).valueOf());
        } else {
          console.error(err);
        }
      })

      var LogPayWinner = diceInstance.logPayWinner({});
      LogPayWinner.watch(function (err, result) {
        if (!err) {
          console.log((result.args.description).valueOf());
          console.log((result.args._playerAddress).valueOf());
          console.log((result.args._winAmount).valueOf());
        } else {
          console.error(err);
        }
      })

     var LogPlayerLose = diceInstance.logPlayerLose({});
     LogPlayerLose.watch(function (err, result) {
       if (!err) {
        console.log((result.args.description).valueOf());
        console.log((result.args._contract).valueOf());
        console.log((result.args._player).valueOf());
        console.log((result.args._rolledDiceNumber).valueOf());
        console.log((result.args._betAmount).valueOf());
       } else {
         console.error(err);
       }
     })

    App.getContractBalance();


    }); 

  },

  getContractBalance: function () {

    var account; 
    web3.eth.getAccounts(async (error, accounts) => {
     account = await accounts[0];
     }); 
    
    App.contracts.Dice.deployed().then(function (contractInstance) {
      return contractInstance.getContractBalance({ from: account }).then(function (v) {
        console.log("Contract balance");
        console.log(web3.fromWei(v.valueOf(), 'ether'));

      }).catch(function (e) {
        console.log(e);      
      });
    });
},

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
