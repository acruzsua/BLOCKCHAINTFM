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

        App.showPlayersInfo();
        App.cleanMaximumBet();
        App.showJackpot();
        App.manageNewEvents();

      });

      return App.bindEvents();
    },

    bindEvents: () => {
    //   $(document).on('click', '.btn-to-dice', function(event){
    //     self.location='./indexdice.html';
    //   });
      $(document).on('click', '.btn-dice', function(event){
        App.roll();
      });


    },

    showJackpot: async () => {
      diceInstance = await App.contracts.Dice.deployed();
      const jackpot = await diceInstance.jackpot();
      document.getElementById("jackpot-amount").innerHTML = web3.fromWei(jackpot, 'ether') + ' ETH';
    },

    showPlayersInfo: async() => {
      diceInstance = await App.contracts.Dice.deployed();

      const showAddress = () => {
        web3.eth.getAccounts(async (error, accounts) => {
          account = await accounts[0];
          accountShorted = account.slice(0, 6) + '...' + account.slice(-4);
          document.getElementById("metamask-player").innerHTML = accountShorted;
        });
      }

      const showHistory = () => {
        diceInstance.allEvents({fromBlock: 0}
          ).get((error, events) => {
              if (!error)
                roundResolvedEvents = events.filter(e => e.event == "RoundResolved");
                App.populateHistoryTable(roundResolvedEvents.map(e => e.args));
          }
          );
      }

      showAddress();
      showHistory();

      // Better, use Metamask's recommendation, polling every 100 ms.
      // https://github.com/MetaMask/faq/blob/master/DEVELOPERS.md#ear-listening-for-selected-account-changes
      web3.eth.getAccounts(async (error, accounts) => {
        account = await accounts[0];

        setInterval(() => {
          if (web3.eth.accounts[0] !== account) {
            account = web3.eth.accounts[0];

            document.getElementById("result").innerHTML = "&nbsp;";
            showAddress();
            showHistory();
          }
        }, 100);
      });
    },

    manageNewEvents: async () => {
        diceInstance = await App.contracts.Dice.deployed();

        web3.eth.getAccounts(async (error, accounts) => {
          account = await accounts[0];

          // This is necessary because with TestRPC blockchain we receive the events twice
          web3.eth.getBlockNumber((error, latestBlock) => {

            // Handle RoundResolved events: write new entry in history tables and show round result
            diceInstance.RoundResolved({fromBlock: latestBlock}
            ).watch((error, event) => {
              if (!error) {
                if(event.blockNumber != latestBlock) {   //accept only new events
                  latestBlock = latestBlock + 1;   //update the latest blockNumber
                  App.populateHistoryTable([event.args]);
                  App.showResult(event.args.rolledDiceNumber);
                  App.showJackpot();
                }
              }
            });

          });

        });
    },

    roll: async () => {

       const betAmount = web3.toWei($('#betAmount').val(), 'ether');
       const risk = ($('#risk').val());

       App.cleanResult();

       const diceInstance = await App.contracts.Dice.deployed();

       web3.eth.getAccounts(async (error, accounts) => {
        const account = await accounts[0];
        const result = await diceInstance.playSoloRound(risk, {from: account, value: betAmount});

        // var LogRolledDiceNumber = diceInstance.logRolledDiceNumber({});
        // LogRolledDiceNumber.watch(function (err, result) {
        //     App.showResult(result.args.rolledDiceNumber.valueOf());

        // })
        })

  },

  showMaxAllowedBet: (MaxAllowedBet) => {
    web3.eth.getAccounts(async (error, accounts) => {
      document.getElementById("MaxAllowedBet").innerHTML = "Maximum bet: " + MaxAllowedBet;
    });
  },

  showResult: (NumberOutcome) => {
    web3.eth.getAccounts(async (error, accounts) => {

    const risk = ($('#risk').val());
    var result;

    if (parseInt(NumberOutcome) > risk)
    {
    result = NumberOutcome + " - You win!";
    }
    else
    {
    result = NumberOutcome + " - You lose!";
    }

    document.getElementById("result").innerHTML = result;
    });
  },

cleanMaximumBet: () => {
    web3.eth.getAccounts(async (error, accounts) => {

    const account = await accounts[0];
    document.getElementById("MaxAllowedBet").innerHTML = "insert bet ...";
    });
},

  cleanResult: () => {
    web3.eth.getAccounts(async (error, accounts) => {
      const account = await accounts[0];
      document.getElementById("result").innerHTML = "waiting ...";
    });
  },

  populateHistoryTable: async (roundsData) => {
    diceInstance = await App.contracts.Dice.deployed();

    web3.eth.getAccounts(async (error, accounts) => {
      account = await accounts[0];

      const getPlayerString = (address, choice, winner) => {
        addressString = address.slice(0, 6) + "..";
        if (address == account) {
          playerString = "YOU" + " - " + choice;
        }
        else {
          playerString = addressString + " - " + choice;
        }

        if (address == winner) {
          playerString = playerString.bold();
        }
        return playerString;
      }

      let table = document.getElementById("last-rounds-table");

      for(let i = 0; i < roundsData.length; i++) {
        // create a new row
        historyData = [
          roundsData[i].roundId,
          getPlayerString(roundsData[i].player, roundsData[i].choice, roundsData[i].winner),
          roundsData[i].rolledDiceNumber,
          web3.fromWei(roundsData[i].betAmount),
          web3.fromWei(roundsData[i].winAmount)
          ];
        let newRow = table.insertRow(1);

        if (table.rows.length >= 16) {
          table.deleteRow(15);
        }

        for(let j = 0; j < historyData.length; j++) {
            // create a new cell
            let cell = newRow.insertCell(j);
            // add value to the cell
            cell.innerHTML = historyData[j];
        }
      }
    });
  },

  };



  $(function() {
    $(window).load(function() {
      App.init();
    });
  });