'use strict';
let gulp = require('gulp');
let moment = require('moment');
let fs = require('fs');
let simpleGit = require('simple-git')();
let semver = require('semver');
let exec = require('child_process').execSync;

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

  fs.writeFileSync('CHANGELOG.md', text);

  // COMMIT
  simpleGit.add('*', () => {
    simpleGit.commit(`Release ${version}`);

    exec('gem build forest_liana.gemspec');
  });
});
