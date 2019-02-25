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
    $.getJSON('RPS.json', data => {
      // Get the necessary contract artifact file and instantiate it with truffle-contract
      const RPSArtifact = data;
      App.contracts.RPS = TruffleContract(RPSArtifact);

      // Set the provider for our contract
      App.contracts.RPS.setProvider(App.web3Provider);

      App.showJackpot();
      App.showPlayersInfo();
      App.manageNewEvents();
    });

    return App.bindEvents();
  },

  bindEvents: () => {
    $(document).on('click', '.btn-rock', function(event){
      App.playRound(0);
    });
    $(document).on('click', '.btn-paper', function(event){
      App.playRound(1);
    });
    $(document).on('click', '.btn-scissors', function(event){
      App.playRound(2);
    });

  },

  manageNewEvents: async () => {
    rpsInstance = await App.contracts.RPS.deployed();

    web3.eth.getAccounts(async (error, accounts) => {
      account = await accounts[0];

      // This is necessary because with TestRPC blockchain we receive the events twice
      web3.eth.getBlockNumber((error, latestBlock) => {

        // Handle RoundResolved events: write new entry in history tables and show round result
        rpsInstance.RoundResolved({fromBlock: latestBlock}
        ).watch((error, event) => {
          if (!error) {
            if(event.blockNumber != latestBlock) {   //accept only new events
              latestBlock = latestBlock + 1;   //update the latest blockNumber
              App.populateHistoryTable([event.args]);
              App.deleteRoundOpenedTable(event.args.roundId);
              if (event.args.player1 == account || event.args.player2 == account) {
                App.showResult(event.args.roundId, event.args.winner);
              }
            }
          }
        });

        // Handle RoundCreated events: add new entry to Opened rounds table is user
        // has created a round.
        rpsInstance.RoundCreated({fromBlock: latestBlock}
        ).watch((error, event) => {
          if (!error) {
            if(event.blockNumber != latestBlock) {   //accept only new events
              latestBlock = latestBlock + 1;   //update the latest blockNumber
              if (!event.args.isSolo) {
                App.populateOpenedRoundsTable([event.args]);
              }
            }
          }
        });
      });

    });
  },

  showJackpot: async () => {
    rpsInstance = await App.contracts.RPS.deployed();
    const jackpot = await rpsInstance.jackpot();
    document.getElementById("jackpot-amount").innerHTML = web3.fromWei(jackpot, 'ether') + ' ETH';
  },

  showPlayersInfo: async() => {
    rpsInstance = await App.contracts.RPS.deployed();

    const showAddress = () => {
      web3.eth.getAccounts(async (error, accounts) => {
        account = await accounts[0];
        accountShorted = account.slice(0, 6) + '...' + account.slice(-4);
        document.getElementById("metamask-player").innerHTML = accountShorted;
      });
    }

    const showHistory = () => {
      rpsInstance.allEvents({fromBlock: 0}
        ).get((error, events) => {
            if (!error)
              roundResolvedEvents = events.filter(e => e.event == "RoundResolved");
              resolvedRounds = roundResolvedEvents.map(e => e.args.roundId.toNumber());
              roundCreatedEvents = events.filter(e => e.event == "RoundCreated");
              openedRounds = roundCreatedEvents.filter(e => !(resolvedRounds.includes(e.args.roundId.toNumber())));
              App.populateHistoryTable(roundResolvedEvents.map(e => e.args));
              App.populateOpenedRoundsTable(openedRounds.map(e => e.args))
        }
        );
    }

    const deleteRowsHistory = tableName => {
      const myTable = document.getElementById(tableName);
      const tableHeaderRowCount = 1;
      const rowCount = myTable.rows.length;
      for (let i = tableHeaderRowCount; i < rowCount; i++) {
        myTable.deleteRow(tableHeaderRowCount);
      }
    }

    showAddress();
    showHistory();

    // Although nicer to detect address change, following doesn't work properly, each time
    // you click on metamask this is launched, althoug you don't change address.
    // web3.currentProvider.publicConfigStore.on('update', () => {
    //   showAddress();
    //   showHistory();
    // });

    // Better, use Metamask's recommendation, polling every 100 ms.
    // https://github.com/MetaMask/faq/blob/master/DEVELOPERS.md#ear-listening-for-selected-account-changes
    web3.eth.getAccounts(async (error, accounts) => {
      account = await accounts[0];

      setInterval(() => {
        if (web3.eth.accounts[0] !== account) {
          account = web3.eth.accounts[0];

          document.getElementById("result").innerHTML = "&nbsp;";
          deleteRowsHistory('last-rounds-table');
          deleteRowsHistory('opened-rounds-table');
          showAddress();
          showHistory();
        }
      }, 100);
    });

  },

  playRound: (choice) => {
    document.getElementById("result").innerHTML = "&nbsp;";

    if ($("#soloPlayer").is(":checked")) {
      App.createRound(true, choice);
    }
    else if ($("#newRound").is(":checked")) {
      App.createRound(false, choice);
    }
    else if ($("#joinRound").is(":checked")){
      App.joinRound($('#round').val(),choice);
    }
  },

  createRound: async (isSolo, choice) => {
    const rpsInstance = await App.contracts.RPS.deployed();

    const betAmount = web3.toWei($('#betAmount').val(), 'ether');

    web3.eth.getAccounts(async (error, accounts) => {
      const account = await accounts[0];

      const result = await rpsInstance.createRound(isSolo, choice, {from: account, value: betAmount});
      if (!isSolo) {
        document.getElementById("result").innerHTML = `New round ${result.logs[0].args.roundId.toNumber()} created`;
      }
      App.showJackpot();

    });
  },

  joinRound: async(roundId, choice) => {
    const rpsInstance = await App.contracts.RPS.deployed();

    const betAmount = web3.toWei($('#betAmount').val(), 'ether');

    web3.eth.getAccounts(async (error, accounts) => {
      const account = await accounts[0];

      await rpsInstance.joinRound(roundId, choice, {from: account, value: betAmount});
      App.showJackpot();

    });
  },

  showResult: (roundId, winner) => {
    web3.eth.getAccounts(async (error, accounts) => {
      const account = await accounts[0];

      if (winner == 0) {
        result = "Draw!";
      }
      else if (winner === account) {
        result = "You win!"
      }
      else {
        result = 'You lost!';
      }

      document.getElementById("result").innerHTML = `Round ${roundId}: ${result}`;
    });
  },

  populateHistoryTable: async (roundsData) => {

    rpsInstance = await App.contracts.RPS.deployed();

    rpsChoices = {0: "R", 1: "P", 2: "S"};

    web3.eth.getAccounts(async (error, accounts) => {
      account = await accounts[0];

      const getPlayerString = (address, choice, winner) => {
        addressString = address.slice(0, 6) + "..";
        if (address == account) {
          playerString = "YOU" + " - " + rpsChoices[choice];
        } else if (address == rpsInstance.address){
          playerString = "House" + " - " + rpsChoices[choice];
        }
         else {
          playerString = addressString + " - " + rpsChoices[choice];
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
          getPlayerString(roundsData[i].player1, roundsData[i].choice1, roundsData[i].winner),
          getPlayerString(roundsData[i].player2, roundsData[i].choice2, roundsData[i].winner),
          web3.fromWei(roundsData[i].betAmount)
          ];
        let newRow = table.insertRow(1);

        if (table.rows.length >= 8) {
          table.deleteRow(7);
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

  populateOpenedRoundsTable: async (roundsData) => {

    rpsInstance = await App.contracts.RPS.deployed();

    web3.eth.getAccounts(async (error, accounts) => {
      account = await accounts[0];

      getPlayerString = (address) => {
        addressString = address.slice(0, 6) + "..";
        if (address == account) {
          playerString = "YOU";
        } else {
          playerString = addressString;
        }

        return playerString;
      }

      let table = document.getElementById("opened-rounds-table");

      for(let i = 0; i < roundsData.length; i++) {
        // create a new row
        historyData = [
          roundsData[i].roundId,
          getPlayerString(roundsData[i].player1),
          web3.fromWei(roundsData[i].betAmount)
          ];
        let newRow = table.insertRow(1);

        for(let j = 0; j < historyData.length; j++) {
            // create a new cell
            let cell = newRow.insertCell(j);
            // add value to the cell
            cell.innerHTML = historyData[j];
        }
      }
    });
  },

  deleteRoundOpenedTable: async (roundId) => {
    let table = document.getElementById("opened-rounds-table");

    for(let i = 1; i < table.rows.length; i++) {
      if (table.rows[i].cells[0].innerHTML == roundId.toNumber()) {
        table.deleteRow(i);
        break;
      }
    }
  },

};

$(function() {
  $(window).load(function() {
    App.init();
  });
});
