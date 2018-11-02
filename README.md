# Forest Admin in Rails [![Build Status](https://travis-ci.org/ForestAdmin/forest-rails.svg?branch=master)](https://travis-ci.org/ForestAdmin/forest-rails)

Forest is a modern Admin Interface (see the [live
demo](https://app.forestadmin.com/login?livedemo)) that works on all major web
frameworks including Rails.

The main difference between *forest_liana* and gems like *Administrate*, *Active Admin*
or *Rails Admin* is that *forest_liana* creates a Rails Engine that automatically
generates a highly flexible admin REST API and deploys a WYSIWYG interface to <a
href="https://www.forestadmin.com/">Forest Admin</a>.

<p align="center" style="margin: 60px 0">
  <img width="70%" src="https://s3.amazonaws.com/forest-assets/screenshot.png" alt="Forest Admin screenshot">
</p>

## Who Uses Forest Admin
- [Apartmentlist](https://www.apartmentlist.com)
- [Carbon Health](https://carbonhealth.com)
- [Ebanx](https://www.ebanx.com)
- [First circle](https://www.firstcircle.ph)
- [Forest Admin](https://www.forestadmin) of course :-)
- [Heetch](https://www.heetch.com)
- [Lunchr](https://www.lunchr.co)
- [Pillow](https://www.pillow.com)
- [Qonto](https://www.qonto.eu)
- [Shadow](https://shadow.tech)
- And hundreds more…

## Installation

[https://docs.forestadmin.com/rails/getting-started/installation](https://docs.forestadmin.com/rails/getting-started/installation)

## Documentation
[https://docs.forestadmin.com/rails](https://docs.forestadmin.com/rails)

## How to contribute

This liana is officially maintained by Forest.
We're always happy to get contributions for other fellow lumberjacks.
All contributions will be reviewed by Forest's team before being merged into master.

Here is the contribution workflow:

1. **Fork** the repo on GitHub
2. **Clone** the project to your own machine
3. **Commit** changes to your own branch
4. **Push** your work back up to your fork
5. Submit a **Pull request** so that we can review your changes

Please ensure that the **tests** are passing before submitting any pull request:
```
$ RAILS_ENV=test bundle exec rake --trace db:migrate test
```

## Licence

[GPL v3](https://github.com/ForestAdmin/forest-rails/blob/master/LICENSE)
