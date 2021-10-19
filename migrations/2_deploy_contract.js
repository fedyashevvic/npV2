// eslint-disable-next-line no-undef
const AI = artifacts.require('AI')
// eslint-disable-next-line no-undef
const AIRouter = artifacts.require('AIRouter')

module.exports = async function(deployer) {
  await deployer.deploy(AI, '1000000000000000000000000');
  const aiContract = await AI.deployed();
  // const pair = await aiContract.ai2bnb();
  // console.log(pair)

  // const router = await deployer.deploy(AIRouter, aiContract.address);
  await deployer.deploy(AIRouter, aiContract.address);
  // await aiContract.changeTaxAddressAndAmount(pair, router.address, '50');
}