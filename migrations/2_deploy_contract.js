// eslint-disable-next-line no-undef
const Hibiki = artifacts.require('Hibiki')

module.exports = function(deployer) {
  // Deploy Mock DAI Token
  deployer.deploy(Hibiki);
}