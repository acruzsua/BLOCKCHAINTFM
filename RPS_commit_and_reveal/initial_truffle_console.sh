var a0 = () => { return web3.fromWei(web3.eth.getBalance(web3.eth.accounts[0]).toNumber()) }
var a1 = () => { return web3.fromWei(web3.eth.getBalance(web3.eth.accounts[1]).toNumber()) }
var a2 = () => { return web3.fromWei(web3.eth.getBalance(web3.eth.accounts[2]).toNumber()) }
var a3 = () => { return web3.fromWei(web3.eth.getBalance(web3.eth.accounts[3]).toNumber()) }

addr0 = web3.eth.accounts[0]
addr1 = web3.eth.accounts[1]
addr2 = web3.eth.accounts[2]
addr3 = web3.eth.accounts[3]


fundGame = (account, ethers) => RPS.at(RPS.address).fundGame({ from: web3.eth.accounts[account], value: web3.toWei(ethers) })

console.log('hola1')
fundGame(0,5)
console.log('hola2')

RPS.at(RPS.address).startGame()

RPS.at(RPS.address).createRound(true, 0, {value: web3.toWei(1)})
