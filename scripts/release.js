'use strict';
require('dotenv').config();
const moment = require('moment');
const fs = require('fs');
const simpleGit = require('simple-git')();
const semver = require('semver');
const exec = require('child_process').execSync;
const { ReleaseNoteManager } = require('@forestadmin/devops');

const { DEVOPS_SLACK_TOKEN, DEVOPS_SLACK_CHANNEL } = process.env;
const OPTIONS = { releaseIcon: '🌱', withVersion: true };

const BRANCH_MASTER = 'master';
const BRANCH_DEVEL = 'devel';
const PRERELEASE_OPTIONS = ['premajor', 'preminor', 'prepatch', 'prerelease'];
const RELEASE_OPTIONS = ['major', 'minor', 'patch', ...PRERELEASE_OPTIONS];

function build() {
  const parseCommandLineArguments = () => {
    let releaseType = 'patch';
    let prereleaseTag;

    if (process.argv) {
      if (process.argv[2]) {
        const option = process.argv[2].replace('--', '');
        if (RELEASE_OPTIONS.includes(option)) {
          releaseType = option;
        }
      }
      if (process.argv[3]) {
        const option = process.argv[3].replace('--', '');
        prereleaseTag = option;
      } else if (PRERELEASE_OPTIONS.includes(releaseType)) {
        prereleaseTag = 'beta';
      }
    }

    return { releaseType, prereleaseTag };
  };

  const gitPullErrorCatcher = (error) => {
    if (error) {
      throw new Error('Git Pull Error');
    }
  };

  const getBranchLabel = (branchName) => branchName || 'current branch';

  const pullAndCommitChanges = async (newPackageFile, newVersionFile, newChanges, commitMessage, branchName) => {
    if (branchName) {
      await simpleGit.checkout(branchName);
    }

    return simpleGit
      .pull(gitPullErrorCatcher)
      .exec(() => { console.log(`Pull ${getBranchLabel(branchName)} done.`); })
      .exec(() => {
        fs.writeFileSync('lib/forest_liana/version.rb', newVersionFile);
        fs.writeFileSync('package.json', newPackageFile);
        fs.writeFileSync('CHANGELOG.md', newChanges);
      })
      .add(['CHANGELOG.md', 'package.json'])
      .then(() => { exec('bundle install'); })
      .add('*')
      .commit(commitMessage)
      .push()
      .exec(() => { console.log(`Commit Release on ${getBranchLabel(branchName)} done.`); })
      .then(() => { exec('gem build forest_liana.gemspec'); });
  };

  const addTagToGit = (tag, branchName) => simpleGit
    .addTag(tag)
    .push('origin', tag)
    .exec(() => { console.log(`Tag ${tag} on ${getBranchLabel(branchName)} done.`); });

  const mergeDevelOntoMaster = () => simpleGit
    .checkout(BRANCH_MASTER)
    .pull(gitPullErrorCatcher)
    .exec(() => { console.log(`Pull ${BRANCH_MASTER} done.`); })
    .mergeFromTo(BRANCH_DEVEL, BRANCH_MASTER)
    .exec(() => { console.log(`Merge ${BRANCH_DEVEL} on ${BRANCH_MASTER} done.`); })
    .push();

  let releaseType = 'patch';
  let prereleaseTag;

  ({ releaseType, prereleaseTag } = parseCommandLineArguments());

  // VERSION (version.rb)
  let versionFile = fs.readFileSync('lib/forest_liana/version.rb').toString().split('\n');
  let version = versionFile[1].match(/\w*VERSION = "(.*)"/)[1];
  version = semver.inc(version, releaseType, prereleaseTag);
  versionFile[1] = `  VERSION = "${version}"`;
  const newVersionFile = versionFile.join('\n');

  // VERSION (package.json)
  const packageContents = fs.readFileSync('./package.json', 'utf8');
  const packageJson = JSON.parse(packageContents);
  packageJson.version = version;
  const newPackageFile = JSON.stringify(packageJson, null, 2);

  // CHANGELOG
  const changes = fs.readFileSync('CHANGELOG.md').toString().split('\n');
  const today = moment().format('YYYY-MM-DD');

  const index = changes.indexOf('## [Unreleased]') + 1;
  changes.splice(index, 0, `\n## RELEASE ${version} - ${today}`);
  const newChanges = changes.join('\n');

  const commitMessage = `chore(release): ${version}`;
  const tag = `v${version}`;

  return new Promise((resolve) => {
    simpleGit.status((_, statusSummary) => {
      const currentBranch = statusSummary.current;

      let promise;
      if (prereleaseTag || /v\d+(\.\d+)?/i.test(currentBranch)) {
        promise = pullAndCommitChanges(newPackageFile, newVersionFile, newChanges, commitMessage, currentBranch)
          .then(() => addTagToGit(tag, currentBranch));
      } else {
        promise = pullAndCommitChanges(newPackageFile, newVersionFile, newChanges, commitMessage, BRANCH_DEVEL)
          .then(() => mergeDevelOntoMaster())
          .then(() => addTagToGit(tag, BRANCH_MASTER))
          .then(() => simpleGit.checkout(BRANCH_DEVEL));
      }

      promise.catch(() => {});

      resolve(promise);
    });
  });
}

return build()
  .then(() => new ReleaseNoteManager(DEVOPS_SLACK_TOKEN, DEVOPS_SLACK_CHANNEL, OPTIONS).create())
