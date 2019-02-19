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

     var LogRolledDiceNumber = diceInstance.logRolledDiceNumber({});
     LogRolledDiceNumber.watch(function (err, result) {
       if (!err) {
        console.log("getting number");
        console.log((result.args._rolledDiceNumber).valueOf());
       } else {
         console.error(err);
       }
     })
    }); 
  },

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
