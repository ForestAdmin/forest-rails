module.exports = {
  branches: ['main', {name: 'beta', prerelease: true}],
  plugins: [
    [
      '@semantic-release/commit-analyzer', {
        preset: 'angular',
        releaseRules: [
          // Example: `type(scope): subject [force release]`
          { subject: '*[force release]*', release: 'patch' },
        ],
      },
    ],
    '@semantic-release/release-notes-generator',
    '@semantic-release/changelog',
    [
      '@semantic-release/exec',
      {
        prepareCmd: 'sed -i \'s/forest_liana (.*)/forest_liana (${nextRelease.version})/g\' Gemfile.lock; sed -i \'s/VERSION = ".*"/VERSION = "${nextRelease.version}"/g\' lib/forest_liana/version.rb; sed -i \'s/"version": ".*"/"version": "${nextRelease.version}"/g\' package.json;',
        successCmd: 'touch .trigger-rubygem-release',
      },
    ],
    [
      '@semantic-release/git',
      {
        assets: ['CHANGELOG.md', 'Gemfile.lock', 'lib/forest_liana/version.rb', 'package.json'],
      },
    ],
    '@semantic-release/github',
    'semantic-release-rubygem',
    [
      'semantic-release-slack-bot',
      {
        markdownReleaseNotes: true,
        notifyOnSuccess: true,
        notifyOnFail: false,
        onSuccessTemplate: {
          text: "📦 $package_name@$npm_package_version has been released!",
          blocks: [{
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: '*New `$package_name` package released!*'
            }
          }, {
            type: 'context',
            elements: [{
              type: 'mrkdwn',
              text: "📦  *Version:* <$repo_url/releases/tag/v$npm_package_version|$npm_package_version>"
            }]
          }, {
            type: 'divider',
          }],
          attachments: [{
            blocks: [{
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: '*Changes* of version $release_notes',
              },
            }],
          }],
        },
        packageName: 'forest_liana',
      }
    ],
  ],
}
