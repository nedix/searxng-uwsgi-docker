const { defineConfig } = require('cypress');
const { addMatchImageSnapshotPlugin } = require('@simonsmith/cypress-image-snapshot/plugin');

module.exports = defineConfig({
  e2e: {
    specPattern: `${__dirname}/integration/**/*.cy.{js,jsx,ts,tsx}`,
    supportFile: `${__dirname}/cypress.support.js`,
    setupNodeEvents(on) {
      addMatchImageSnapshotPlugin(on);
    },
  },
  downloadsFolder: `${__dirname}/artifacts/downloads/`,
  fixturesFolder: `${__dirname}/fixtures/`,
  screenshotOnRunFailure: true,
  screenshotsFolder: `${__dirname}/artifacts/screenshots/`,
  video: false,
});
