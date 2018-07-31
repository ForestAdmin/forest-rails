# Change Log

## [Unreleased]

## RELEASE 2.11.5 - 2018-07-31
### Fixed
- Search - Fix the broken search if the collection contains Array fields. [Regression introduced in 2.9.0]
- Search - Highlight the records id if it matches with the search value.

## RELEASE 2.11.4 - 2018-07-31
### Fixed
- Search - Fix the search while typing single quotes in the search value.

## RELEASE 2.11.3 - 2018-07-30
### Fixed
- Records Display - Fix collections display for project using Ruby version inferior to 2.3.0. [Regression introduced in 2.10.1]

## RELEASE 2.11.2 - 2018-07-30
### Fixed
- Smart BelongsTo - Fix the reference field values display in the records list of collections using Smart BelongsTo relationships.

## RELEASE 2.11.1 - 2018-07-30
### Fixed
- Records Count - Fix list display error if the collection name is different from the class name (routing issue to compute the count).

## RELEASE 2.11.0 - 2018-07-19
### Changed
- Performance - Improve the speed of listing the records by executing their count into another request.

## RELEASE 2.10.5 - 2018-07-11
### Fixed
- HasMany Relationships - Fix the performance of the related data retrieval if the collection has hidden belongsTo associations in the list.

## RELEASE 2.10.4 - 2018-07-11
### Fixed
- Mixpanel Integration - Only retrieve events that are less than 60 days old to be compliant with the Mixpanel's API.

## RELEASE 2.10.3 - 2018-07-10
### Fixed
- ActiveStorage - Support ActiveStorage without having to set eager_load property to true in development environments.

## RELEASE 2.10.2 - 2018-07-10
### Fixed
- Smart Views - Fix associated data retrieval from Smart Views (where the fields to retrieve are not specified in the query params).

## RELEASE 2.10.1 - 2018-07-10
### Fixed
- Stripe Integration - Improve the error handling if the customer Stripe Id is not found.
- Stripe Integration - Trial to prevent uninitialized constant errors with Stripe classes.

## RELEASE 2.10.0 - 2018-07-10
### Added
- Mixpanel Integration - Add the integration to display the last 100 Mixpanel events of a "user" record.

## RELEASE 2.9.2 - 2018-07-04
### Fixed
- Database Connection - If the database is not accessible on server start, the liana doesn't send an Apimap anymore (it was a "partial" Apimap in such case).

## RELEASE 2.9.1 - 2018-07-03
### Changed
- Technical - Use the "official" domain for the default server host.

### Fixed
- Record Creation - Fix the search of belongsTo associated records in record creation forms if the belongsTo foreign key is a UUID.

## RELEASE 2.9.0 - 2018-06-28
### Added
- Search - Display highlighted matches on table view when searching.

## RELEASE 2.8.6 - 2018-06-27
### Fixed
- Intercom Integration - Users can now access to the Intercom Details page.

## RELEASE 2.8.5 - 2018-06-26
### Fixed
- Namespacing - Prevent a potential error on server start if a ResourcesController class already exists in another lib of the client project.
- Filters - Filtering on 2 different belongsTo foreign keys referencing the same table now returns the expected records.

## RELEASE 2.8.4 - 2018-06-21
### Changed
- Onboarding - Improve the information message if the liana is properly setup and users run the "rails g forest_liana:install".

### Fixed
- Permissions - Fix automated permission for projects having multiple teams.

## RELEASE 2.8.3 - 2018-06-20
### Fixed
- Onboarding - If the liana is properly setup and users run the "rails g forest_liana:install" command again, the task will be skipped.
- Onboarding - The install generator now supports credentials.yml.enc file introduced in Rails 5.2.

## RELEASE 2.8.2 - 2018-06-18
### Fixed
- Development Autoreload - Prevent "A copy of ForestLiana::ResourcesController has been removed from the module tree but is still active!" in development mode.

## RELEASE 2.8.1 - 2018-06-15
### Changed
- Performance - Make the related data count retrieval much more efficient if the result contains thousands of records.

## RELEASE 2.8.0 - 2018-06-05
### Added
- Permissions - Add a permission mechanism to protect the data accordingly to the UI configuration.

## RELEASE 2.7.0 - 2018-06-01
### Added
- Segments - Users can create segments with SQL queries.

## RELEASE 2.6.1 - 2018-05-29
### Fixed
- Smart Relationships - Fix the serialization of Smart belongs_to relationships in lists and record details.

## RELEASE 2.6.0 - 2018-05-29
### Added
- Smart Actions - "Single" type Smart Action forms can now be prefilled with contextual values.

## RELEASE 2.5.5 - 2018-05-23
### Fixed
- Live Query - Fix the charts in Live query mode when using mysql2 adapter.

## RELEASE 2.5.4 - 2018-05-14
### Fixed
- Records List - Fix records retrieval regression for tables having self-references.

## RELEASE 2.5.3 - 2018-05-09
### Fixed
- Rails 5 - Tables named "applications" are now properly handled using Rails 5+.

## RELEASE 2.5.2 - 2018-04-16
### Fixed
- Rails 5.2 - Support New Rails 5.2 apps with config.action_controller.default_protect_from_forgery set to true.

## RELEASE 2.5.1 - 2018-04-06
### Changed
- Sessions - Improve the error message if the environment secret is missing on session creation.

### Fixed
- Charts - Fix some bad Line charts aggregation due to Daylight Saving Time.

## RELEASE 2.5.0 - 2018-04-03
### Added
- Related Data - Delete records directly from a hasMany listing.

## RELEASE 2.4.9 - 2018-03-21
### Fixed
- Gem ActAsTaggable - Prevent errors on collections that are not taggable. [Regression introduced in 2.4.8]

## RELEASE 2.4.8 - 2018-03-21
### Fixed
- Gem ActAsTaggable - Forest does not make all models taggable anymore.
- Rails Version - Fix a recent incompatibility with Rails 5.1+. [Regression introduced in 2.4.5]

## RELEASE 2.4.7 - 2018-03-21
### Fixed
- HasMany Relationships - Fix data display for projects having namespaced models (second trial). [Regression introduced in 2.3.0]

## RELEASE 2.4.6 - 2018-03-21
### Fixed
- HasMany Relationships - Fix data display for projects having namespaced models. [Regression introduced in 2.3.0]

## RELEASE 2.4.5 - 2018-03-21
### Fixed
- List Views - Fix records retrieval for project using Rails versions from 4.0.0 to 4.2.0. [Regression introduced in 2.3.0]

## RELEASE 2.4.4 - 2018-03-21
### Fixed
- Live Queries - Display the Value Charts properly if no data has been retrieved.

## RELEASE 2.4.3 - 2018-03-05
### Fixed
- Live Query - Fix charts generation for values equal to 0 or null.

## RELEASE 2.4.2 - 2018-03-05
### Fixed
- Errors - Fix a typo on association update error handling.

## RELEASE 2.4.1 - 2018-03-02
### Changed
- Errors - Add the full stack trace in case of internal error calling Forest API.

## RELEASE 2.4.0 - 2018-03-01
### Added
- Smart Actions - Users can define Smart Actions only available in a record detail.

### Fixed
- Smart BelongsTo - Users can now display their records list on collections using Smart BelongsTo. [Regression introduced in 2.3.0]

## RELEASE 2.3.5 - 2018-02-28
### Fixed
- Smart Actions - Display the Smart Actions form fields in the declaration order. [Regression introduced in 2.3.0]

## RELEASE 2.3.4 - 2018-02-27
### Fixed
- Search - Prevent the records search to crash if no fields parameter is sent by the client.
- Error Handling - Send a 500 status code in case of internal server error (instead of a 404).

## RELEASE 2.3.3 - 2018-02-21
### Fixed
- Devise - Users now have a password field and can create records for models using Devise gem.

## RELEASE 2.3.2 - 2018-02-21
### Added
- Filters - Add a new "is after X hours ago" operator to filter on date fields.

## RELEASE 2.3.1 - 2018-02-09
### Fixed
- Live Queries - Prevent the execution of obvious "write" queries.
- Live Queries - Prevent the execution of multiple queries.

## RELEASE 2.3.0 - 2018-02-08
### Changed
- Apimap - Prevent random sorting collections and useless updates.
- Smart Fields - Compute only the necessary Smart Fields values for list views and CSV exports.

## RELEASE 2.2.2 - 2018-01-30
### Fixed
- Smart Collections - Fix a regression on fields values serialization.

## RELEASE 2.2.1 - 2018-01-30
### Fixed
- Initialisation - Fix a potential error on database type retrieval on server start.

## RELEASE 2.2.0 - 2018-01-26
### Added
- Charts - Users can create charts using raw database queries with the Live Query option.

### Fixed
- Security - Remove Rails vulnerabilities upgrading the gem version.

## RELEASE 2.1.1 - 2018-01-17
### Fixed
- Start - Prevent a crash if the server is restarting while Forest services are in maintenance.

## RELEASE 2.1.0 - 2018-01-11
### Added
- Authentication - Users can connect to their project using Google Single Sign-On.

### Changed
- Dependencies - Upgrade the json gem to work with Ruby versions 2.4.X on OSX.

## RELEASE 2.0.4 - 2018-01-08
### Changed
- Performance - Set the CORS Max-Age to 1 day to be consistent with the other lianas behaviour.

### Fixed
- Serializer - Fix 'already defined' warning message from serializer on server start.

## RELEASE 2.0.3 - 2017-12-11
### Fixed
- Server Start - Prevent potential error on server start [regression introduced by the version 2].
- Collection Names - Make collection names containing colons valid for the Forest UI.

## RELEASE 2.0.2 - 2017-12-08
### Fixed
- Records Display - Prevent potential collections display regression due to missing Serializers since version 2.0.1.

## RELEASE 2.0.1 - 2017-12-06
### Fixed
- Initialisation - Remove potential warnings on server start.

## RELEASE 2.0.0 - 2017-11-24
### Added
- STI Models - Support STI Models with a collection for the parent model and each child model, with automatic segments on the parent collection.

### Changed
- Collections Names - Collection names are now based on the model name.

## RELEASE 1.9.8 - 2017-11-16
### Added
- Stripe Integration - Allow users to display Stripe records in the Details view.

### Fixed
- Stripe Integration - Fix the global integration when mapped on namespaced models.
- Stripe Integration - Fix the access to customer subscriptions and bank accounts.
- Line Charts - Use ISO 8601 format to display weeks in Line Charts.
- Line Charts - Force the starting day of the week to Monday for Line Charts per week.

## RELEASE 1.9.7 - 2017-10-30
### Fixed
- HasMany Getter - Fix HasMany associated records retrieval for namespaced models.

## RELEASE 1.9.6 - 2017-10-26
### Changed
- Smart Fields - Prevent the Smart Fields computation errors to generate a crash and handle it letting the value empty.
- Intercom Integration - Prefer Intercom access_token configuration to old fashioned app_id/api_key.

## RELEASE 1.9.5 - 2017-10-19
### Fixed
- Smart Field - Fix Smart Fields values serialization for namespaced models.

## RELEASE 1.9.4 - 2017-10-18
### Fixed
- Filters - Fix one-relationships filters on collections based on namespaced models.

## RELEASE 1.9.3 - 2017-10-18
### Fixed
- Export CSV - Enable the CSV export for namespaced models.

## RELEASE 1.9.2 - 2017-10-16
### Fixed
- Charts - Fix belongsTo filters on enum fields.

## RELEASE 1.9.1 - 2017-10-04
### Fixed
- Filters - Fix filters on associations enum fields.

## RELEASE 1.9.0 - 2017-10-02
### Added
- Smart Fields - Add a "is_filterable" option to let them appear in the filters selection.

## RELEASE 1.8.1 - 2017-09-26
### Fixed
- Pie Charts - Fix enum values display on Pie Charts for latest Rails version users.

## RELEASE 1.8.0 - 2017-09-20
### Added
- Smart Fields - Add a parameter to specify if the sorting is allowed on this field.
- Smart Search - Developers can configure a Smart Search on a hasMany relationship.

### Changed
- Smart Collections - Facilitate the way to create Smart Collections.

## RELEASE 1.7.10 - 2017-09-15
### Fixed
- Onboarding - Fix the automatic secrets.yml setup on projects using Rails 5.1+.

## RELEASE 1.7.9 - 2017-09-15
### Fixed
- Stripe - Fix the Stripe Payments access.

## RELEASE 1.7.8 - 2017-09-07
### Added
- Search - Developers can configure in which fields the search will be executed.

## RELEASE 1.7.7 - 2017-08-29
### Added
- Paranoid Mode - Support Paranoia gem and hide all "deleted" data in Forest.

## RELEASE 1.7.6 - 2017-08-24
### Fixed
- Exports - Add a new protection while formatting the data, if an associated record is not found.

## RELEASE 1.7.5 - 2017-08-24
### Fixed
- Exports - Require missing lib for CSV formatting.

## RELEASE 1.7.4 - 2017-08-24
### Fixed
- Exports - Fix some issues with the new export feature.

## RELEASE 1.7.3 - 2017-08-23
### Fixed
- Exports - Fix bad initial implementation for exports authentication.

## RELEASE 1.7.2 - 2017-08-22
### Fixed
- Validations - Do not consider validations if an Active Record before_validation Callback is defined in the model.

## RELEASE 1.7.1 - 2017-08-22
### Fixed
- Validations - Do not consider conditional validations for Forest forms validation.

## RELEASE 1.7.0 - 2017-08-21
### Added
- Exports - Forest can now handle large data exports.
- Search - Split "simple" and "deep" search features with a new param.

## RELEASE 1.6.17 - 2017-08-08
### Added
- Validations - Start the support of forms validations (with 6 first validations).
- Fields - Send the defaultValue for creation forms.

### Changed
- Technical - Update .gemspec file to specify that Rails 3 is not maintained anymore.

### Fixed
- Record Updates - Do not try to update the Smart Fields if no new value is send in the update request.

## RELEASE 1.6.16 - 2017-08-03
### Fixed
- Pie Charts - Fix potential pie chart rendering issue using Rails 5.

## RELEASE 1.6.15 - 2017-07-11
### Added
- Search - Users can search on the hasMany associated data of a specific record.

### Fixed
- Deprecation Warning - Remove a deprecation warning on Chart request due to uniq method.

## RELEASE 1.6.14 - 2017-07-05
### Added
- Filters - Add the before x hours operator.

### Changed
- Errors - Improve error handling on Record creation and update.

### Fixed
- Router - Catch resources routing errors with a 404 response instead of a crash.

## RELEASE 1.6.13 - 2017-06-23
### Added
- Apimap - Send database type and orm version in apimap.

### Fixed
- Records Updates - Fix unexpected "serialize" field update on other record attributes update.
- Development Autoreload - Prevent "A copy of ForestLiana::ResourcesController has been removed from the module tree but is still active!" in development mode.

## RELEASE 1.6.12 - 2017-06-20
### Fixed
- Records Updates - Display an error message on record update on "serialize" field having a nil value.

## RELEASE 1.6.11 - 2017-06-13
### Fixed
- Error Messages - Display an explicit warning if Forest servers are in maintenance.
- Charts - Fix charts having filters on associations fields.

## RELEASE 1.6.10 - 2017-05-30
### Added
- Smart Collections - Add a new isSearchable property to display the search bar for Smart Collections.
- Filters - Add the not contains operator.

## RELEASE 1.6.7 - 2017-05-24
### Fixed
- Pie Charts - Fix Sum Pie charts on a non-id column with at least one filter on an association.
- Filters - Retrieve the right records for filters with conditions on belongsTo foreign key being blank.

## RELEASE 1.6.6 - 2017-05-16
### Added
- Multi-Database - Developers can display models having the same table name on different databases.

## RELEASE 1.6.5 - 2017-05-12
### Added
- Filter - Support AND and OR filters on acts_as_taggable_on attributes

## RELEASE 1.6.4 - 2017-05-09
### Fixed
- Ruby 2.3 - Avoid to use Hash#dig to support version earlier than Ruby 2.3.

## RELEASE 1.6.3 - 2017-05-05
### Fixed
- Apimap - Prevent the bad detection of database collections as Smart Collections if lib/forest_liana is loaded before the models.

## RELEASE 1.6.2 - 2017-05-04
### Added
- Smart Actions - Support file download.
- Smart Fields - Support belongs_to smart fields.
- Smart Fields - Add an explicit error message if the search on a Smart Field generates an error.
- Papertrail - Make Papertrail Versions visible in the records "Related Data".
- Papertrail - Changes made using Forest are now tracked with Papertrail.

### Fixed
- Smart Fields - A search on a collection having Smart Fields with search method implemented will respond properly (bypassing failing Smart Fields search if any).

## RELEASE 1.6.1 - 2017-04-26
### Fixed
- Smart Fields - Smart Fields having a setter are not read-only by default anymore.

## RELEASE 1.6.0 - 2017-04-25
### Added
- Smart Fields - Developers can now define Smart Fields setters.

## RELEASE 1.5.26 - 2017-04-21
### Fixed
- Record Deletion - Fix the records deletion on Rails 5.1.
- Filters ToDate - Fix the end of period filtering for "toDate" date operator types.

## RELEASE 1.5.25 - 2017-04-14
### Added
- Setup Guide - Add integration field to the collections to distinguish Smart Collections and Collections from integrations.

### Fixed
- Server Start - Fix the server crash on start while offline.
- Server Start - Fix the server crash on start while Forest is down (Heroku error page case).

## RELEASE 1.5.24 - 2017-04-06
### Added
- Version Warning - Display a warning message if the liana version used is too old.

### Fixed
- Value Charts - Fix Value Charts computing on collections having a foreign keys that is not named "id".
- Records Deletion - Fix records deletion on collections having a foreign keys that is not named "id".
- STI Models - Fix the display of the parent STI model.

## RELEASE 1.5.23 - 2017-04-05
### Fixed
- STI Models - Add a dropdown with predefined existing STI type values in create/update forms.
- STI Models - Children models do not generate a specific collection anymore (only parent model).

## RELEASE 1.5.22 - 2017-04-05
### Fixed
- Self-referenced models - Users can update their records if the model has both a belongsTo and a hasMany self-reference associations.

## RELEASE 1.5.21 - 2017-04-04
### Fixed
- HasMany - Fix the hasMany SQL request on some Rails versions.

## RELEASE 1.5.20 - 2017-03-30
### Added
- Performance - Do not eager load the associations for the resources count if there is no search or filters on associations.

### Changed
- Analyzer - Force to unuse namespace for ActionController.

## RELEASE 1.5.19 - 2017-03-30
### Fixed
- Analyzer - Fix the router controller name.

## RELEASE 1.5.18 - 2017-03-29
### Added
- Smart Actions - Users don't have to select records to use a smart action through the global option.

### Fixed
- Analyzer - Avoid class name conflict with the "Application" model name.

## RELEASE 1.5.17 - 2017-03-26
### Fixed
- Pie Charts - Fix the computation of Pie Charts having a groupBy on a belongsTo relationship.

## RELEASE 1.5.16 - 2017-03-24
### Fixed
- Records deletion - Fix the deletion of records.

## RELEASE 1.5.15 - 2017-03-21
### Changed
- Devise - Create a smart action automatically to change a devise password.

## RELEASE 1.5.14 - 2017-03-16
### Changed
- CORS - Enable all forestadmin.com subdomains to requests the liana.
- Analyzer - Avoid to analyze the tables without an ActiveRecord models.

### Fixed
- Record Getter - Prevent an unexpected error if the record does not exist.

## RELEASE 1.5.13 - 2017-03-13
### Changed
- Smart business logic - Users can override the admin API per resource.

## RELEASE 1.5.12 - 2017-03-09
### Changed
- Analyzer - Always retrieve the parent STI class instead of a random children.

## RELEASE 1.5.11 - 2017-02-21
### Fixed
- Filters - Fix filters on boolean fields using MySQL databases.
- Stripe - Fix Stripe invoices/cards/... display for "complex" model names.

## RELEASE 1.5.10 - 2017-02-09
### Fixed
- Image Upload - Support Paperclip validates_attachment_file_name option.

## RELEASE 1.5.9 - 2017-02-02
### Fixed
- Search - Fix search on collections using UUID as a primary key.

## RELEASE 1.5.8 - 2017-01-29
### Fixed
- Deprecation warnings - Silent deprecation warnings for removed "serialized_attributes" in Rails 5.

## RELEASE 1.5.7 - 2017-01-24
### Fixed
- BelongsTo association - Fix the update of a record when a belongsTo association uses a custom foreign key.

## RELEASE 1.5.6 - 2016-01-17
### Fixed
- Devise - Users can update a record details without resetting the devise password.

## RELEASE 1.5.5 - 2016-01-10
### Fixed
- Rake - Avoid to initialize Forest when running a Rake task.

## RELEASE 1.5.4 - 2016-01-05
### Fixed
- Dashboard - Fix the dashboard display when the chart payloads are "force-utf8-encoded".

## RELEASE 1.5.3 - 2016-01-05
### Fixed
- Authentication - Fix the authentication when Forest.user_class_name opt is present.

## RELEASE 1.5.2 - 2016-01-04
### Added
- Column Types - Support JSON and JSONB column types.

### Fixed
- Tests - Fix test fixtures using dynamic dates.

## RELEASE 1.5.1 - 2016-12-23
### Fixed
- Resources Getter - Fix the retrieval of records having attributes with special characters (ex: Â) on MySQL.

## RELEASE 1.5.0 - 2016-12-12
### Added
- Segments - Smart Segments can be created to define specific records subsets.

### Changed
- Configuration - Rename secret values to env_secret and auth_secret.
- Installation - Add the env_secret as an option instead of prompt it.
- Installation - Store the env_secret and auth_secret in config/secrets.yml.
- Installation - auth_secret and env_secret are nil by default in all non-development environments and need to be set manually.

### Fixed
- Pagination - Set the default hasMany page size to 5 to be consistent with other lianas.
- Search - Support the search for MySQL databases.
- Sorting - Support the sorting on belongsTo columns for MySQL databases.

## RELEASE 1.4.7 - 2016-12-05
### Added
- Configuration - Catch a missing auth_key in the configuration and send an explicit error message on liana authentication.

### Changed
- Date Filters - Date filters operators are now based on the client timezone.
- Pie Charts - Pie charts grouped by dates now display dates in the client timezone (instead of the raw SQL value).

## RELEASE 1.4.6 - 2016-11-28
### Fixed
- Rails 5 - Fix app start crash regression due to "serialize" support.

## RELEASE 1.4.5 - 2016-11-25
### Added
- Model Fields - Support "serialize" option for String type fields.
- Pie Charts - Support Pie charts with a group by on an association field.
- Smart field - Allow to override the read_only option of a Smart Field.
- Errors Tracking - Catch errors on app launch / apimap generation / liana session creation.

### Changed
- Authentication - Add an option to set the model name for internal forest user authentication option.

### Fixed
- App Start - Prevent crash and display a warning for each associations badly declared in the models.
- Resources Getter - Fix possible ambiguous id attribute in the query select.

## RELEASE 1.4.4 - 2016-11-18
### Changed
- Rails 5 - Remove deprecation warnings with empty responses.

### Fixed
- App Start - Fix some applications starts crash due to CORS injection on frozen middleware.

## RELEASE 1.4.3 - 2016-11-15
### Added
- Chart Filters - Support chart filters on belongsTo associations.

### Fixed
- Date Filters - Fix the date operators broken in release 1.4.2.

## RELEASE 1.4.2 - 2016-11-15
### Fixed
- Ruby 2.0 - Fix the chart creation when a date operator is present.

## RELEASE 1.4.1 - 2016-11-11
### Fixed
- Rails 5 - Fix application start using Rails liana 1.4.0.

## RELEASE 1.4.0 - 2016-11-10
### Added
- Field Type - Support Time field type.

### Fixed
- Polymorphism - Fix polymorphic "hasMany" on record hasMany association retrieval.
- Collections Customization - Fix the smart collections/fields/actions use if the lib/forest_liana directory is eager loaded by the app.

## RELEASE 1.3.53 - 2016-11-04
### Fixed
- Records Edition - Fix a regression when serializing the Create/Update response.

## RELEASE 1.3.52 - 2016-11-04
### Changed
- Performance - Request only displayed fields in the records list.
- SQL Errors - SQL errors are now send in the response after a record creation or update.

## RELEASE 1.3.51 - 2016-11-01
### Fixed
- Rails 3 - Fix a regression when computing charts for Rails 3 applications.

## RELEASE 1.3.50 - 2016-10-31
### Added
- CORS - Users can deactivate Forest CORS headers.

## RELEASE 1.3.49 - 2016-10-31
### Fixed
- Ruby 1.9 - Allow UTF-8 characters in the source code.

## RELEASE 1.3.48 - 2016-10-28
### Added
- Analyzer - Support STI models.

### Changed
- Filters - Add the new date filters protocol.
- Pie Charts - Display enum labels instead of integers for a "group by" on enum field.

### Fixed
- Rails 5 - Fix the way to discover models in Rails 5 - abstract class.
- Rails 5 - Fix deprecation warnings.
- Custom Action - Fix the bad endpoints if some actions have the same name.

## RELEASE 1.3.47 - 2016-10-19
### Added
- Analyzer - Add the included_models options.

## RELEASE 1.3.46 - 2016-10-18
### Added
- Analyzer - Add the excluded_models options.

## RELEASE 1.3.45 - 2016-10-14
### Added
- Analyzer - Add the included_models options.
- Analyzer - Add the excluded_models options.

## RELEASE 1.3.45 - 2016-10-14
### Added
- Devise - Support password management with Devise Authenticable.

### Fixed
- Error handling - Display the right errors on create/update.
- Value Charts - Fix previous period count regression due to filterType introduction.
- Smart fields - Enable search on smart fields.
- Fields - Serialize the "isVirtual" property in the apimap.

## RELEASE 1.3.44 - 2016-10-11
### Fixed
- Deserialization - Ensure data->attributes is present before deserializing

## RELEASE 1.3.43 - 2016-10-11
### Added
- Fields - Users want to view/edit their array of integers.

### Fixed
- Polymorphism - Fix the nullification of a polymorphic has_one association.
- Serializer - Set the relationship to nil if the record is not found instead of crashing.
- Models - Fix the way we discovered the active record models.

## RELEASE 1.3.42 - 2016-10-03
### Fixed
- Smart field - Ensure the serializer exists before creating the smart field.
- Record Create - Fix empty relationships on record creation.

## RELEASE 1.3.41 - 2016-09-26
### Added
- Filters - Users want the OR filter operator with their conditions (restricted to simple conditions).
- Schema - Support UUID field type.

### Fixed
- Record Update - Fix the potential dissociations on record update.
- Search - Support search on ID of type 'String'.

## RELEASE 1.3.40 - 2016-09-26
### Added
- Filters - Users want to have "From now" and "Today" operators.

### Fixed
- Charts - Fix value chart with filters and a previous period comparison.
