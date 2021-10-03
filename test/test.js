const { assert } = require('chai');
const Web3 = require('web3');
const dexABI = [{"inputs":[{"internalType":"address","name":"_factory","type":"address"},{"internalType":"address","name":"_WETH","type":"address"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"WETH","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"},{"internalType":"uint256","name":"amountADesired","type":"uint256"},{"internalType":"uint256","name":"amountBDesired","type":"uint256"},{"internalType":"uint256","name":"amountAMin","type":"uint256"},{"internalType":"uint256","name":"amountBMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"addLiquidity","outputs":[{"internalType":"uint256","name":"amountA","type":"uint256"},{"internalType":"uint256","name":"amountB","type":"uint256"},{"internalType":"uint256","name":"liquidity","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"amountTokenDesired","type":"uint256"},{"internalType":"uint256","name":"amountTokenMin","type":"uint256"},{"internalType":"uint256","name":"amountETHMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"addLiquidityETH","outputs":[{"internalType":"uint256","name":"amountToken","type":"uint256"},{"internalType":"uint256","name":"amountETH","type":"uint256"},{"internalType":"uint256","name":"liquidity","type":"uint256"}],"stateMutability":"payable","type":"function"},{"inputs":[],"name":"factory","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"},{"internalType":"uint256","name":"reserveIn","type":"uint256"},{"internalType":"uint256","name":"reserveOut","type":"uint256"}],"name":"getAmountIn","outputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"}],"stateMutability":"pure","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"reserveIn","type":"uint256"},{"internalType":"uint256","name":"reserveOut","type":"uint256"}],"name":"getAmountOut","outputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"}],"stateMutability":"pure","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"}],"name":"getAmountsIn","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"}],"name":"getAmountsOut","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountA","type":"uint256"},{"internalType":"uint256","name":"reserveA","type":"uint256"},{"internalType":"uint256","name":"reserveB","type":"uint256"}],"name":"quote","outputs":[{"internalType":"uint256","name":"amountB","type":"uint256"}],"stateMutability":"pure","type":"function"},{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"amountAMin","type":"uint256"},{"internalType":"uint256","name":"amountBMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"removeLiquidity","outputs":[{"internalType":"uint256","name":"amountA","type":"uint256"},{"internalType":"uint256","name":"amountB","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"amountTokenMin","type":"uint256"},{"internalType":"uint256","name":"amountETHMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"removeLiquidityETH","outputs":[{"internalType":"uint256","name":"amountToken","type":"uint256"},{"internalType":"uint256","name":"amountETH","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"amountTokenMin","type":"uint256"},{"internalType":"uint256","name":"amountETHMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"removeLiquidityETHSupportingFeeOnTransferTokens","outputs":[{"internalType":"uint256","name":"amountETH","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"amountTokenMin","type":"uint256"},{"internalType":"uint256","name":"amountETHMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"bool","name":"approveMax","type":"bool"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"name":"removeLiquidityETHWithPermit","outputs":[{"internalType":"uint256","name":"amountToken","type":"uint256"},{"internalType":"uint256","name":"amountETH","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"token","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"amountTokenMin","type":"uint256"},{"internalType":"uint256","name":"amountETHMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"bool","name":"approveMax","type":"bool"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"name":"removeLiquidityETHWithPermitSupportingFeeOnTransferTokens","outputs":[{"internalType":"uint256","name":"amountETH","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"},{"internalType":"uint256","name":"liquidity","type":"uint256"},{"internalType":"uint256","name":"amountAMin","type":"uint256"},{"internalType":"uint256","name":"amountBMin","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"bool","name":"approveMax","type":"bool"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"name":"removeLiquidityWithPermit","outputs":[{"internalType":"uint256","name":"amountA","type":"uint256"},{"internalType":"uint256","name":"amountB","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapETHForExactTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactETHForTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactETHForTokensSupportingFeeOnTransferTokens","outputs":[],"stateMutability":"payable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForETH","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForETHSupportingFeeOnTransferTokens","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint256","name":"amountOutMin","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapExactTokensForTokensSupportingFeeOnTransferTokens","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"},{"internalType":"uint256","name":"amountInMax","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapTokensForExactETH","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"},{"internalType":"uint256","name":"amountInMax","type":"uint256"},{"internalType":"address[]","name":"path","type":"address[]"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"deadline","type":"uint256"}],"name":"swapTokensForExactTokens","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"nonpayable","type":"function"},{"stateMutability":"payable","type":"receive"}];

const factoryAbi = [{"inputs":[{"internalType":"address","name":"_feeToSetter","type":"address"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"token0","type":"address"},{"indexed":true,"internalType":"address","name":"token1","type":"address"},{"indexed":false,"internalType":"address","name":"pair","type":"address"},{"indexed":false,"internalType":"uint256","name":"","type":"uint256"}],"name":"PairCreated","type":"event"},{"constant":true,"inputs":[],"name":"INIT_CODE_PAIR_HASH","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"allPairs","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"allPairsLength","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"}],"name":"createPair","outputs":[{"internalType":"address","name":"pair","type":"address"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"feeTo","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"feeToSetter","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"getPair","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"_feeTo","type":"address"}],"name":"setFeeTo","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"internalType":"address","name":"_feeToSetter","type":"address"}],"name":"setFeeToSetter","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"}];


const web3 = new Web3('http://localhost:7545/');
// eslint-disable-next-line no-undef
const Hibiki = artifacts.require("Hibiki");

require('chai')
  .use(require('chai-as-promised'))
  .should()

function tokens(n) {
  // eslint-disable-next-line no-undef
  return web3.utils.toWei(n, 'ether');
}

// eslint-disable-next-line no-undef
contract('AI & Router', async (accounts) => {
  let ai, router, routerAddress, aiAddress, balance, pair;
  const owner = accounts[0];
  const taxbaleAddress = accounts[1];

  const _dexRouter = '0x3380aE82e39E42Ca34EbEd69aF67fAa0683Bb5c1'; // APE
  const dexRouter = new web3.eth.Contract(dexABI, _dexRouter);

  let WETH, _factoryAddress, factoryRouter;

  // ganache-cli --fork https://data-seed-prebsc-1-s1.binance.org:8545/ -p 7545 -l 0xFFFFFFFF
  // eslint-disable-next-line no-undef
  before(async () => {
    WETH = await dexRouter.methods.WETH().call();
    _factoryAddress = await dexRouter.methods.factory().call();
    factoryRouter = new web3.eth.Contract(factoryAbi, _factoryAddress);

    // Load Contracts
    ai = await Hibiki.new();
    aiAddress = ai.address;
    console.log(owner, aiAddress)

    balance = async (address) => {
      const rawBalance = await ai.balanceOf(address);
      const balance = rawBalance.toString();
      return balance;
    }
  })

  describe('Contract created and balance loaded', async () => {
    it('Has a name', async () => {
      const name = await ai.name()
      assert.equal(name, 'Hibiki.finance')
    })

    it('Has a balance', async () => {
      let wBalance = await balance(owner);
      assert.equal(wBalance, tokens('10000000'))
    })
  })

  describe('Test regular transactions', async () => {
    it('Sending a regular transaction', async () => {
      await ai.transfer(taxbaleAddress, tokens('200'), {from: owner});
      let wBalance = await balance(taxbaleAddress);
      assert.equal(wBalance, tokens('200'));
    })
  })

  describe('Add liquidity to DEX', async () => {
    it('Sending a liq transaction', async () => {
      const timestamp = Date.now();
      await ai.approve(_dexRouter, tokens('10000'), {from: owner});
      const tx =  await dexRouter.methods.addLiquidityETH(
        aiAddress,
        tokens('10000'),
        '0',
        '0',
        owner,
        timestamp
      ).send({from: owner, value: tokens('1'), gas: '1000000'});
      console.log(tx);
    })
  });

  describe('Check liquidity', async () => {
    it('Checking the liq balance', async () => {
      const pair = await factoryRouter.methods.getPair(aiAddress, WETH).call();
      console.log(pair)
      const liquidity = await balance(pair);
      assert.equal(liquidity, tokens('10000'));
    })
  })

  describe('Test trade transactions ETH -> AI', async () => {
    it('Sending a trade tx transaction', async () => {
      const timestamp = Date.now();
      const path = [WETH, ai.address];
      await dexRouter.methods.swapExactETHForTokensSupportingFeeOnTransferTokens(
        '0',
        path,
        owner,
        timestamp
      ).send({from: taxbaleAddress, value: tokens('0.1'), gas: '500000'});
      let ABalance = await web3.eth.getBalance(ai.address);
      let AiBalance = await balance(ai.address);
      console.log('AI BALANCE', AiBalance);
      console.log('BNB BALANCE', ABalance);
      // assert.notEqual(AiBalance, tokens('0'));
      // assert.equal(ABalance, tokens('0'));


    })
  })

  describe('Test trade transactions ETH -> AI', async () => {
    it('Sending a trade tx transaction', async () => {
      const timestamp = Date.now();
      const path = [WETH, ai.address];
      await dexRouter.methods.swapExactETHForTokensSupportingFeeOnTransferTokens(
        '0',
        path,
        owner,
        timestamp
      ).send({from: taxbaleAddress, value: tokens('0.1'), gas: '500000'});
      let ABalance = await web3.eth.getBalance(ai.address);
      let AiBalance = await balance(ai.address);
      console.log('AI BALANCE', AiBalance);
      console.log('BNB BALANCE', ABalance);
      // assert.notEqual(AiBalance, tokens('0'));
      // assert.equal(ABalance, tokens('0'));


    })
  })

  describe('Test trade transactions AI -> ETH', async () => {
    it('Sending a trande tx transaction', async () => {
      const timestamp = Date.now();
      const path = [ai.address, WETH];
      await ai.approveMax(_dexRouter, {from: taxbaleAddress});
      await dexRouter.methods.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokens('500'),
        '0',
        path,
        owner,
        timestamp
      ).send({from: taxbaleAddress, value: 0, gas: '500000'});
      let BNBBalance = await web3.eth.getBalance(ai.address);
      let AiBalance= await balance(ai.address);

      // console.log(BBalance.toString(), ABalance.toString())
      console.log('BNB BALANCE', BNBBalance);
      console.log('AI BALANCE', AiBalance);
      // assert.notEqual(BNBBalance, tokens('0'));
    })
  })

  describe('Test trade transactions AI -> ETH', async () => {
    it('Sending a trande tx transaction', async () => {
      const timestamp = Date.now();
      const path = [ai.address, WETH];
      await ai.approveMax(_dexRouter, {from: taxbaleAddress});
      await dexRouter.methods.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokens('100'),
        '0',
        path,
        owner,
        timestamp
      ).send({from: taxbaleAddress, value: 0, gas: '500000'});
      let BNBBalance = await web3.eth.getBalance(ai.address);
      let AiBalance= await balance(ai.address);

      // console.log(BBalance.toString(), ABalance.toString())
      console.log('BNB BALANCE', BNBBalance);
      console.log('AI BALANCE', AiBalance);
      // assert.notEqual(BNBBalance, tokens('0'));
    })
  })

  // describe('Add liquidity to DEX second time', async () => {
  //   it('Sending a liq transaction', async () => {
  //     // const blockNum = await web3.eth.getBlockNumber();
  //     const timestamp = Date.now();
  //     // await ai.approve(_dexRouter, tokens('100'), {from: owner});
  //     const tx = await dexRouter.methods.addLiquidityETH(
  //       aiAddress,
  //       tokens('100'),
  //       '0',
  //       '0',
  //       owner,
  //       timestamp
  //     ).send({from: owner, value: tokens('1'), gas: '2000000'});
  //     let {data} = tx;
  //     console.log(data)
  //     // let wBalance = await balance(owner);
  //     let treasuryBalance = await balance('0x51228d1FA3dCD52CCE7D08A1F3Db51c53F5Fb3fF');
  //     // assert.equal(wBalance, tokens('100'));
  //     console.log('TREASURY', treasuryBalance)
  //   })
  // });


   // describe('Test trade transactions', async () => {
  //   // it('checks tax amount', async () => {
  //   //   const taxAmount = await ai.getTaxAmount();
  //   //   assert.equal(taxAmount, 5);
  //   // })

  //   it('Sending transaction from trade', async () => {
  //     await ai.approve(owner, tokens('100'));
  //     await ai.transferFrom(owner, taxbaleAddress, tokens('100'), {from: owner});
  //     const ownerBalance = await ai.balanceOf(owner);
  //     const ownerB = ownerBalance.toString();
  //     // const tax1 = await ai.balanceOf(taxAddress1);
  //     // const tax1B = tax1.toString();
  //     // const tax2 = await ai.balanceOf(taxAddress2);
  //     // const tax2B = tax2.toString();
  //     assert.equal(ownerB, tokens('200'));

  //     // assert.equal(tax1B, tokens('2.5'));
  //     // assert.equal(tax2B, tokens('2.5'));

  //     const lAI = await router.lAI();
  //     const lBNB = await router.lBNB();
  //     console.log('OUTPUT', lAI.toString(), lBNB.toString())

  //     const deBalance = await web3.eth.getBalance(_devPoolAddress);
  //     console.log(deBalance)
  //     // assert.isAbove(deBalance.toString(), 0);

  //   })
  // })

  // describe('Admin adds trande address', async () => {
  //   it('Adding an address', async () => {
  //     const tradeAddr = await ai.ai2bnb();
  //     await ai.addTradeAddress(tradeAddr, {from: owner});
  //     console.log(tradeAddr)
  //     assert.equal(true, true);
  //   })
  // })
});

// ganache-cli --fork https://mainnet.infura.io/v3/90b60c78e08a4022b5cfae77b2d399bf -p 7545 -l 0xFFFFFFFF