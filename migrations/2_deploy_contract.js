// eslint-disable-next-line no-undef
const AI = artifacts.require('AI')

module.exports = function(deployer) {
  // Deploy Mock DAI Token
  deployer.deploy(AI);
}