'use strict';
const gulp = require('gulp');
const moment = require('moment');
const fs = require('fs');
const simpleGit = require('simple-git')();
const semver = require('semver');
const exec = require('child_process').execSync;

let BRANCH_MASTER = 'master';
let BRANCH_DEVEL = 'devel';

gulp.task('build', () => {
  let numberToIncrement = 'patch';
  if (process.argv && process.argv[3]) {
    const option = process.argv[3].replace('--', '');
    if (['major', 'minor', 'patch'].indexOf(option) !== -1) {
      numberToIncrement = option;
    }
  }

  // VERSION
  let versionFile = fs.readFileSync('lib/forest_liana/version.rb').toString().split('\n');
  let version = versionFile[1].match(/\w*VERSION = "(.*)"/)[1];
  version = semver.inc(version, numberToIncrement);
  versionFile[1] = `  VERSION = "${version}"`;
  fs.writeFileSync('lib/forest_liana/version.rb', versionFile.join('\n'));

  // BUNDLE
  exec('bundle install');

  // CHANGELOG
  let data = fs.readFileSync('CHANGELOG.md').toString().split('\n');
  let today = moment().format('YYYY-MM-DD');

  data.splice(3, 0, `\n## RELEASE ${version} - ${today}`);
  let text = data.join('\n');

  simpleGit
    .checkout(BRANCH_DEVEL)
    .then(function() { console.log('Starting pull on ' + BRANCH_DEVEL + '...'); })
    .pull(function(error) { if (error) { console.log(error); } })
    .then(function() { console.log(BRANCH_DEVEL + ' pull done.'); })
    .then(function() { fs.writeFileSync('CHANGELOG.md', text); })
    .add('*')
    .commit(`Release ${version}`)
    .push()
    .checkout(BRANCH_MASTER)
    .then(function() { console.log('Starting pull on ' + BRANCH_MASTER + '...'); })
    .pull(function(error) { if (error) { console.log(error); } })
    .then(function() { console.log(BRANCH_MASTER + ' pull done.'); })
    .mergeFromTo(BRANCH_DEVEL, BRANCH_MASTER)
    .push();
    .then(function() { exec('gem build forest_liana.gemspec'); });
});
