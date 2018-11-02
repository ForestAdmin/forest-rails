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

## Getting Started

[https://docs.forestadmin.com/rails/getting-started/installation](https://docs.forestadmin.com/rails/getting-started/installation)

## Documentation
[https://docs.forestadmin.com/rails](https://docs.forestadmin.com/rails)

## What is it for?

### Browse your application's data
Unleash the power of your data in the simplest way.

<img width="300px" src="https://www.forestadmin.com/public/img/illustrations/home/forest-browse-data.svg" alt="Browser">

### Manipulate your data

Provide your operational team with a tool with which they can perform any actions towards your customers' success.

<img width="300px" src="https://www.forestadmin.com/public/img/illustrations/home/forest-manipulate-data.svg" alt="Manipulate">

### Listen to your data

Anticipate/predict your customer needs before they're even able to formulate it for better lead nurturing, trial conversion, and upsells.

<img width="300px" src="https://www.forestadmin.com/public/img/illustrations/home/forest-listen-data.svg" alt="Listen">


### Organize your application's data
Backend architecture can be immensely complex. Forest will scan your ORM to retrieve the database models, and generate an admin REST API that will communicate directly with our back office interface.

<img width="300px" src="https://www.forestadmin.com/public/img/illustrations/home/forest-organise-data.svg" alt="Organize">

### Reconcile your data

Bring additional intelligence and consistency by leveraging data from third party services coupled with your application’s data in a single interface.

<img width="300px" src="https://www.forestadmin.com/public/img/illustrations/home/forest-reconciliate-data.svg" alt="Reconcile">

### Streamline your workflow

Forest fits into your existing workflows and provides you with the framework to streamline those business processes effortlessly.

<img width="300px" src="https://www.forestadmin.com/public/img/illustrations/home/forest-streamline-data.svg" alt="Streamline">

### Collaborate on your data

As your team grows, so do all the little things it takes for your operations to run smoothly. With Forest, simplify collaboration and productivity all across your office.

<img width="300px" src="https://www.forestadmin.com/public/img/illustrations/home/forest-collaborate-data.svg" alt="Collaborate">




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
