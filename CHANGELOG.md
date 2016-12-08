# Change Log

## [Unreleased]
### Added
- Segments - Smart Segments can be created to define specific records subsets.

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
