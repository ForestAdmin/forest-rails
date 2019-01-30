'use strict';
const gulp = require('gulp');
const moment = require('moment');
const fs = require('fs');
const simpleGit = require('simple-git')();
const semver = require('semver');
const exec = require('child_process').execSync;

let BRANCH_MASTER = 'master';
let BRANCH_DEVEL = 'devel';
let RELEASE_OPTIONS = ['major', 'minor', 'patch', 'premajor', 'preminor', 'prepatch', 'prerelease'];

gulp.task('build', () => {
  let releaseType = 'patch';
  let prereleaseTag;

  if (process.argv) {
    if (process.argv[3]) {
      const option = process.argv[3].replace('--', '');
      if (RELEASE_OPTIONS.includes(option)) {
        releaseType = option;
      }
    }
    if (process.argv[4]) {
      const option = process.argv[4].replace('--', '');
      prereleaseTag = option;
    }
  }

  // VERSION
  let versionFile = fs.readFileSync('lib/forest_liana/version.rb').toString().split('\n');
  let version = versionFile[1].match(/\w*VERSION = "(.*)"/)[1];
  version = semver.inc(version, releaseType, prereleaseTag);
  versionFile[1] = `  VERSION = "${version}"`;
  const newVersionFile = versionFile.join('\n');

  // CHANGELOG
  let changes = fs.readFileSync('CHANGELOG.md').toString().split('\n');
  let today = moment().format('YYYY-MM-DD');

  changes.splice(3, 0, `\n## RELEASE ${version} - ${today}`);
  const newChanges = changes.join('\n');

  const tag = `v${version}`;

  simpleGit
    .checkout(BRANCH_DEVEL)
    .pull((error) => { if (error) { console.log(error); } })
    .then(() => { console.log(`Pull ${BRANCH_DEVEL} done.`); })
    .then(() => {
      fs.writeFileSync('lib/forest_liana/version.rb', newVersionFile);
      fs.writeFileSync('CHANGELOG.md', newChanges);
    })
    .then(() => { exec('bundle install'); })
    .add('*')
    .commit(`Release ${version}`)
    .push()
    .then(() => { console.log(`Commit Release on ${BRANCH_DEVEL} done.`); })
    .checkout(BRANCH_MASTER)
    .pull((error) => { if (error) { console.log(error); } })
    .then(() => { console.log(`Pull ${BRANCH_MASTER} done.`); })
    .mergeFromTo(BRANCH_DEVEL, BRANCH_MASTER)
    .then(() => { console.log(`Merge ${BRANCH_DEVEL} on ${BRANCH_MASTER} done.`); })
    .push()
    .then(() => { exec('gem build forest_liana.gemspec'); })
    .addTag(tag)
    .push('origin', tag)
    .then(() => { console.log(`Tag ${tag} on ${BRANCH_MASTER} done.`); })
    .checkout(BRANCH_DEVEL);
});
