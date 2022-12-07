## [7.7.3](https://github.com/ForestAdmin/forest-rails/compare/v7.7.2...v7.7.3) (2022-12-07)


### Bug Fixes

* **charts:** remove any sort on chart and remove default join behaviour on line chart ([#588](https://github.com/ForestAdmin/forest-rails/issues/588)) ([2de4c83](https://github.com/ForestAdmin/forest-rails/commit/2de4c837462bea9acc7f958fa06c5c751590f2bc))

## [7.7.2](https://github.com/ForestAdmin/forest-rails/compare/v7.7.1...v7.7.2) (2022-11-21)


### Bug Fixes

* **serializer:** serialize only the foreignKeys of belongsTo relations ([#587](https://github.com/ForestAdmin/forest-rails/issues/587)) ([3695f97](https://github.com/ForestAdmin/forest-rails/commit/3695f972a382f1c35ea0da42eb0af06793dc39be))

## [7.7.1](https://github.com/ForestAdmin/forest-rails/compare/v7.7.0...v7.7.1) (2022-10-20)


### Bug Fixes

* onboard issue with openid_connect gem when running "rails g forest_liana:install"  ([#586](https://github.com/ForestAdmin/forest-rails/issues/586)) ([18347c5](https://github.com/ForestAdmin/forest-rails/commit/18347c53e695541e55fed9dc5ebb60cb5c8774e5)), closes [#585](https://github.com/ForestAdmin/forest-rails/issues/585)

# [7.7.0](https://github.com/ForestAdmin/forest-rails/compare/v7.6.14...v7.7.0) (2022-09-14)


### Features

* **auth:** remove callbackUrl parameter on authentication and remove forest_agent_url (FOREST_APPLICATION_URL) variable ([#582](https://github.com/ForestAdmin/forest-rails/issues/582)) ([00bfb3a](https://github.com/ForestAdmin/forest-rails/commit/00bfb3ab50a9aa4e5f742ef41cf30e108addff34))

## [7.6.14](https://github.com/ForestAdmin/forest-rails/compare/v7.6.13...v7.6.14) (2022-09-08)


### Bug Fixes

* **charts:** user with permissions level that allows charts creation or edition should always be allow to perform charts requests  released ([#583](https://github.com/ForestAdmin/forest-rails/issues/583)) ([e6611e9](https://github.com/ForestAdmin/forest-rails/commit/e6611e9c1adc2411439a8d88fa6259bd85b4e183))

## [7.6.13](https://github.com/ForestAdmin/forest-rails/compare/v7.6.12...v7.6.13) (2022-08-23)


### Bug Fixes

* dynamic scopes ([#580](https://github.com/ForestAdmin/forest-rails/issues/580)) ([890eead](https://github.com/ForestAdmin/forest-rails/commit/890eeadd73eb6485c75041103a42df20384f9a73))

## [7.6.12](https://github.com/ForestAdmin/forest-rails/compare/v7.6.11...v7.6.12) (2022-08-09)


### Bug Fixes

* **sti:** remove unnecessary sti detection and always use actual model instead of parent ([#579](https://github.com/ForestAdmin/forest-rails/issues/579)) ([a159ad0](https://github.com/ForestAdmin/forest-rails/commit/a159ad0b51fe3a8d79e38a96673efbba85995136))

## [7.6.11](https://github.com/ForestAdmin/forest-rails/compare/v7.6.10...v7.6.11) (2022-08-01)


### Bug Fixes

* use stable sort for schema fields so we get same results across OS ([#577](https://github.com/ForestAdmin/forest-rails/issues/577)) ([359d396](https://github.com/ForestAdmin/forest-rails/commit/359d396c27e152ad4f2aaaa096a8dd285183b3a4)), closes [#575](https://github.com/ForestAdmin/forest-rails/issues/575)

## [7.6.10](https://github.com/ForestAdmin/forest-rails/compare/v7.6.9...v7.6.10) (2022-08-01)


### Bug Fixes

* **multidb:** fix issue with multiple connection detection ([#578](https://github.com/ForestAdmin/forest-rails/issues/578)) ([3a3340b](https://github.com/ForestAdmin/forest-rails/commit/3a3340b147fd5fcc7ce94d6a27249d505ac516fb))

## [7.6.9](https://github.com/ForestAdmin/forest-rails/compare/v7.6.8...v7.6.9) (2022-07-22)


### Bug Fixes

* **security:** patch tzinfo dependency vulnerabilities ([#573](https://github.com/ForestAdmin/forest-rails/issues/573)) ([9793917](https://github.com/ForestAdmin/forest-rails/commit/97939176d11d7b9f0545a2394f3d22faccefd846))

## [7.6.8](https://github.com/ForestAdmin/forest-rails/compare/v7.6.7...v7.6.8) (2022-07-20)


### Bug Fixes

* **multidb:** allow associations across databases to work properly ([#572](https://github.com/ForestAdmin/forest-rails/issues/572)) ([0f6261d](https://github.com/ForestAdmin/forest-rails/commit/0f6261d22dd59d39ccf7c783555fa9176abe6f62))

## [7.6.7](https://github.com/ForestAdmin/forest-rails/compare/v7.6.6...v7.6.7) (2022-06-29)


### Bug Fixes

* remove default sort on columns created_at & id in the query builder ([fd734fc](https://github.com/ForestAdmin/forest-rails/commit/fd734fc8f581262cb922b0b95921506c6494e37d))

## [7.6.6](https://github.com/ForestAdmin/forest-rails/compare/v7.6.5...v7.6.6) (2022-06-29)


### Bug Fixes

* take into account subclasses of ActiveRecord models ([#569](https://github.com/ForestAdmin/forest-rails/issues/569)) ([2298081](https://github.com/ForestAdmin/forest-rails/commit/22980817c2e5edeb437c32da404e75e79e8cb8bf))

## [7.6.5](https://github.com/ForestAdmin/forest-rails/compare/v7.6.4...v7.6.5) (2022-06-21)


### Bug Fixes

* prevent duplication of models from multiple ActiveRecord application classes ([#566](https://github.com/ForestAdmin/forest-rails/issues/566)) ([3a135b7](https://github.com/ForestAdmin/forest-rails/commit/3a135b79a91544e9b37fe07345acdfe1ff6a2554))

## [7.6.4](https://github.com/ForestAdmin/forest-rails/compare/v7.6.3...v7.6.4) (2022-06-20)


### Bug Fixes

* handle instance dependent associations ([#567](https://github.com/ForestAdmin/forest-rails/issues/567)) ([43f60a3](https://github.com/ForestAdmin/forest-rails/commit/43f60a3b7a0f67981697e2b724b89e396bd30016))

## [7.6.3](https://github.com/ForestAdmin/forest-rails/compare/v7.6.2...v7.6.3) (2022-05-19)


### Bug Fixes

* sort fields in schema ([#561](https://github.com/ForestAdmin/forest-rails/issues/561)) ([d5eff3c](https://github.com/ForestAdmin/forest-rails/commit/d5eff3c2134d69417121fcb07c6252ee4c011534))
* **search:** fix search on fields of type UUID ([#560](https://github.com/ForestAdmin/forest-rails/issues/560)) ([f997659](https://github.com/ForestAdmin/forest-rails/commit/f997659925670fe03c336a2924317ce04de9d67b))

## [7.6.2](https://github.com/ForestAdmin/forest-rails/compare/v7.6.1...v7.6.2) (2022-05-11)


### Bug Fixes

* **apimap:** fix generate schema with unknown action ([#555](https://github.com/ForestAdmin/forest-rails/issues/555)) ([92a0da4](https://github.com/ForestAdmin/forest-rails/commit/92a0da47fe207d188793f88d9bf4fa8a6edade0a))

## [7.6.1](https://github.com/ForestAdmin/forest-rails/compare/v7.6.0...v7.6.1) (2022-05-10)


### Bug Fixes

* typo on deactivated count response ([#559](https://github.com/ForestAdmin/forest-rails/issues/559)) ([43f7c5b](https://github.com/ForestAdmin/forest-rails/commit/43f7c5b73f087c7be75dc501fcc773963b4a340f))

# [7.6.0](https://github.com/ForestAdmin/forest-rails/compare/v7.5.1...v7.6.0) (2022-05-03)


### Features

* **cors:** add access control allow private network handling ([#554](https://github.com/ForestAdmin/forest-rails/issues/554)) ([7832b4c](https://github.com/ForestAdmin/forest-rails/commit/7832b4c7554fd2f9ea89aa9118770ebc57cabbf6))

## [7.5.1](https://github.com/ForestAdmin/forest-rails/compare/v7.5.0...v7.5.1) (2022-03-31)


### Bug Fixes

* add support count deactivate on relationships resources ([#552](https://github.com/ForestAdmin/forest-rails/issues/552)) ([4d24c0f](https://github.com/ForestAdmin/forest-rails/commit/4d24c0fd473bc3f7d2b455ebce43670cfa9478a5))

# [7.5.0](https://github.com/ForestAdmin/forest-rails/compare/v7.4.5...v7.5.0) (2022-03-29)


### Features

* **count:** add deactivate count support ([#547](https://github.com/ForestAdmin/forest-rails/issues/547)) ([06423f9](https://github.com/ForestAdmin/forest-rails/commit/06423f9bbd4470fa32b745ec5840f8596383cd2e))

## [7.4.5](https://github.com/ForestAdmin/forest-rails/compare/v7.4.4...v7.4.5) (2021-12-22)


### Bug Fixes

* onboarding with rails 7 when running "rails g forest_liana:install" ([#539](https://github.com/ForestAdmin/forest-rails/issues/539)) ([6fcee9b](https://github.com/ForestAdmin/forest-rails/commit/6fcee9b00cf71cd717680854397016442a4c2d99))

## [7.4.4](https://github.com/ForestAdmin/forest-rails/compare/v7.4.3...v7.4.4) (2021-12-22)


### Bug Fixes

* revert "fix: update arel-helpers dependency ([#535](https://github.com/ForestAdmin/forest-rails/issues/535))" ([#537](https://github.com/ForestAdmin/forest-rails/issues/537)) ([7b75556](https://github.com/ForestAdmin/forest-rails/commit/7b755567a89c6fe59b8280c8ce2f62e2def0b4ba))

## [7.4.3](https://github.com/ForestAdmin/forest-rails/compare/v7.4.2...v7.4.3) (2021-12-21)


### Bug Fixes

* update arel-helpers dependency ([#535](https://github.com/ForestAdmin/forest-rails/issues/535)) ([176afff](https://github.com/ForestAdmin/forest-rails/commit/176afff36718964768401e03d89de583db810514))

## [7.4.2](https://github.com/ForestAdmin/forest-rails/compare/v7.4.1...v7.4.2) (2021-12-16)


### Bug Fixes

* add user inside context for smart actions hooks ([#532](https://github.com/ForestAdmin/forest-rails/issues/532)) ([8d71e9c](https://github.com/ForestAdmin/forest-rails/commit/8d71e9c957d305dfb365d455a5abdef019ae2569))

## [7.4.1](https://github.com/ForestAdmin/forest-rails/compare/v7.4.0...v7.4.1) (2021-11-22)


### Bug Fixes

* avoid attaching smart action hooks on pre-defined smart actions ([#526](https://github.com/ForestAdmin/forest-rails/issues/526)) ([baab51f](https://github.com/ForestAdmin/forest-rails/commit/baab51f4c95011a5cc11f2bb9ce42be82e92713b))

# [7.4.0](https://github.com/ForestAdmin/forest-rails/compare/v7.3.0...v7.4.0) (2021-11-04)


### Features

* **reporter:** customers can now catch every errors thrown by forest ([#519](https://github.com/ForestAdmin/forest-rails/issues/519)) ([c040b73](https://github.com/ForestAdmin/forest-rails/commit/c040b7351177757bb6d43a9111bcd175a372c219))

# [7.3.0](https://github.com/ForestAdmin/forest-rails/compare/v7.2.2...v7.3.0) (2021-10-13)


### Features

* **filter:** handle correctly uuid field type ([#525](https://github.com/ForestAdmin/forest-rails/issues/525)) ([22be1a8](https://github.com/ForestAdmin/forest-rails/commit/22be1a8d032b8fb56b96464fcfecf03514b48cbc))

## [7.2.2](https://github.com/ForestAdmin/forest-rails/compare/v7.2.1...v7.2.2) (2021-09-30)


### Bug Fixes

* **authentication:** fix certificate issues that break the authentication ([#522](https://github.com/ForestAdmin/forest-rails/issues/522)) ([0caa6c5](https://github.com/ForestAdmin/forest-rails/commit/0caa6c561055e892504b9df8181ab2142c2ea9d4))

## [7.2.1](https://github.com/ForestAdmin/forest-rails/compare/v7.2.0...v7.2.1) (2021-09-29)


### Bug Fixes

* smart actions restricted to a segment using segment query should be visible ([#510](https://github.com/ForestAdmin/forest-rails/issues/510)) ([6bb4439](https://github.com/ForestAdmin/forest-rails/commit/6bb4439dee11da92e4aa89a1d2b57a2aa02938a2))

# [7.2.0](https://github.com/ForestAdmin/forest-rails/compare/v7.1.0...v7.2.0) (2021-09-10)


### Features

* **filter:** add "is in" filter ([#518](https://github.com/ForestAdmin/forest-rails/issues/518)) ([020310c](https://github.com/ForestAdmin/forest-rails/commit/020310c80e9aee2d39e77301ec97577e1b26f8ee))

# [7.1.0](https://github.com/ForestAdmin/forest-rails/compare/v7.0.2...v7.1.0) (2021-08-25)


### Features

* include tags in the user data inside the request ([#515](https://github.com/ForestAdmin/forest-rails/issues/515)) ([91e9bb9](https://github.com/ForestAdmin/forest-rails/commit/91e9bb93e954c9f8e03191497dd1a8fae7fb4fcf))

## [7.0.2](https://github.com/ForestAdmin/forest-rails/compare/v7.0.1...v7.0.2) (2021-08-16)


### Bug Fixes

* **hooks:** smart action hooks response correctly send back serialized fields ([#514](https://github.com/ForestAdmin/forest-rails/issues/514)) ([794f9a7](https://github.com/ForestAdmin/forest-rails/commit/794f9a7b45a828cc7971a4d7f21192dc0ed2edd3))

## [7.0.1](https://github.com/ForestAdmin/forest-rails/compare/v7.0.0...v7.0.1) (2021-07-23)


### Bug Fixes

* restrict the use of surrounding parentheses only to in operator ([2e8d0cd](https://github.com/ForestAdmin/forest-rails/commit/2e8d0cdf05d9a1a0bb509bb0f67beff0136a1b19))
* restrict the use of surrounding parentheses only to IN operator ([17df2c0](https://github.com/ForestAdmin/forest-rails/commit/17df2c017fdaa7d5904a9dc3307e9c7ec8e69570))

# [7.0.0](https://github.com/ForestAdmin/forest-rails/compare/v6.6.2...v7.0.0) (2021-07-20)


### Bug Fixes

* **dependency:** now using forestadmin-jsonapi-serializers instead of the jsonapi-serializers gem ([#475](https://github.com/ForestAdmin/forest-rails/issues/475)) ([3feea36](https://github.com/ForestAdmin/forest-rails/commit/3feea36b3b578638f3ad7c16ebab8e457a68d71f))


### chore

* **force-release:** now using forestadmin-jsonapi-serializers instead of the jsonapi-serializers gem ([#464](https://github.com/ForestAdmin/forest-rails/issues/464)) ([00ee2a4](https://github.com/ForestAdmin/forest-rails/commit/00ee2a40ded4eaccbe7fecb68e4edf0aaa36e38b))


### Features

* **scopes:** enforce scopes restrictions on a wider range of requests ([#488](https://github.com/ForestAdmin/forest-rails/issues/488)) ([66825a3](https://github.com/ForestAdmin/forest-rails/commit/66825a339fc11d03b8a1653b1877cb9d492dacfb))
* smart action hooks now have access to the http request ([#499](https://github.com/ForestAdmin/forest-rails/issues/499)) ([5cd4a0e](https://github.com/ForestAdmin/forest-rails/commit/5cd4a0e7b9d9e1fcc551198a2eab62e471f51d92))
* **hooks:** developers can dynamically add or remove smart actions fields ([#465](https://github.com/ForestAdmin/forest-rails/issues/465)) ([970f3d8](https://github.com/ForestAdmin/forest-rails/commit/970f3d82806296137f2e64379c92884b04954580))
* **security:** secure segments queries ([#495](https://github.com/ForestAdmin/forest-rails/issues/495)) ([571f889](https://github.com/ForestAdmin/forest-rails/commit/571f889d85c226b8d4b78618150c75f4fa2aa9ad))


### BREAKING CHANGES

* record is no longer send to the hook midleware & values option on smart action is no longer supported
* **hooks:** fields parameters on hook function is no longer a map of field, it is now an array.
change hook is no longer choosen by the field name, field need to have hook defined inside it definition by addin a props hook.
* **dependency:** Switch from jsonapi-serializers to forestadmin-jsonapi-serializers to serialize data to the JSONAPI format, mainly to avoid conflict with the jsonapi-serializer library
* **force-release:** Switch from jsonapi-serializers to forestadmin-jsonapi-serializers to serialize data to the JSONAPI format, mainly to avoid conflict with the jsonapi-serializer library

# [7.0.0-beta.6](https://github.com/ForestAdmin/forest-rails/compare/v7.0.0-beta.5...v7.0.0-beta.6) (2021-07-20)


### Bug Fixes

* allow smart action endpoints to start with slashes ([d4f6a61](https://github.com/ForestAdmin/forest-rails/commit/d4f6a618aeea72364b0e7511545b67fbbfb17c99))
* allow smart action endpoints to start with slashes ([cf6c6a9](https://github.com/ForestAdmin/forest-rails/commit/cf6c6a96498e6813e4b7ccaa56cacd9abefc332f))
* fix time based graph when timezone is different with database ([#476](https://github.com/ForestAdmin/forest-rails/issues/476)) ([5d9fb89](https://github.com/ForestAdmin/forest-rails/commit/5d9fb8903ae53615dd1789bdebbc4d9c7d6f4576))
* stats permissions should be retrieved only one time per team ([#489](https://github.com/ForestAdmin/forest-rails/issues/489)) ([c2e9104](https://github.com/ForestAdmin/forest-rails/commit/c2e9104ebf32deeb3e5676706fdcbaae5de34869))
* support permissions infos with ruby < 2.7 ([#486](https://github.com/ForestAdmin/forest-rails/issues/486)) ([a611271](https://github.com/ForestAdmin/forest-rails/commit/a611271e709bb6a9ed0d3ebccfb64b6eea1d324d))


### Features

* include role in the user data inside the request ([#478](https://github.com/ForestAdmin/forest-rails/issues/478)) ([0a34716](https://github.com/ForestAdmin/forest-rails/commit/0a347165897aa118e486895e55f4b29ba7fb888b))
* **schema:** move some meta data under stack attribute to prevent blocking scenarios on DWO ([#469](https://github.com/ForestAdmin/forest-rails/issues/469)) ([76aa754](https://github.com/ForestAdmin/forest-rails/commit/76aa7540300f75b0ea1d00ec3b60e4976b7d800e))

# [7.0.0-beta.5](https://github.com/ForestAdmin/forest-rails/compare/v7.0.0-beta.4...v7.0.0-beta.5) (2021-07-09)


### Features

* **scopes:** enforce scopes restrictions on a wider range of requests ([#488](https://github.com/ForestAdmin/forest-rails/issues/488)) ([66825a3](https://github.com/ForestAdmin/forest-rails/commit/66825a339fc11d03b8a1653b1877cb9d492dacfb))

# [7.0.0-beta.4](https://github.com/ForestAdmin/forest-rails/compare/v7.0.0-beta.3...v7.0.0-beta.4) (2021-07-06)


### Features

* smart action hooks now have access to the http request ([#499](https://github.com/ForestAdmin/forest-rails/issues/499)) ([5cd4a0e](https://github.com/ForestAdmin/forest-rails/commit/5cd4a0e7b9d9e1fcc551198a2eab62e471f51d92))


### BREAKING CHANGES

* record is no longer send to the hook midleware & values option on smart action is no longer supported

# [7.0.0-beta.3](https://github.com/ForestAdmin/forest-rails/compare/v7.0.0-beta.2...v7.0.0-beta.3) (2021-07-02)


### Features

* **security:** secure segments queries ([#495](https://github.com/ForestAdmin/forest-rails/issues/495)) ([571f889](https://github.com/ForestAdmin/forest-rails/commit/571f889d85c226b8d4b78618150c75f4fa2aa9ad))

## [6.6.2](https://github.com/ForestAdmin/forest-rails/compare/v6.6.1...v6.6.2) (2021-06-16)


### Bug Fixes

* stats permissions should be retrieved only one time per team ([#489](https://github.com/ForestAdmin/forest-rails/issues/489)) ([c2e9104](https://github.com/ForestAdmin/forest-rails/commit/c2e9104ebf32deeb3e5676706fdcbaae5de34869))

## [6.6.1](https://github.com/ForestAdmin/forest-rails/compare/v6.6.0...v6.6.1) (2021-06-10)


### Bug Fixes

* support permissions infos with ruby < 2.7 ([#486](https://github.com/ForestAdmin/forest-rails/issues/486)) ([a611271](https://github.com/ForestAdmin/forest-rails/commit/a611271e709bb6a9ed0d3ebccfb64b6eea1d324d))

# [6.6.0](https://github.com/ForestAdmin/forest-rails/compare/v6.5.1...v6.6.0) (2021-06-09)


### Features

* include role in the user data inside the request ([#478](https://github.com/ForestAdmin/forest-rails/issues/478)) ([0a34716](https://github.com/ForestAdmin/forest-rails/commit/0a347165897aa118e486895e55f4b29ba7fb888b))

## [6.5.1](https://github.com/ForestAdmin/forest-rails/compare/v6.5.0...v6.5.1) (2021-06-08)


### Bug Fixes

* allow smart action endpoints to start with slashes ([d4f6a61](https://github.com/ForestAdmin/forest-rails/commit/d4f6a618aeea72364b0e7511545b67fbbfb17c99))
* allow smart action endpoints to start with slashes ([cf6c6a9](https://github.com/ForestAdmin/forest-rails/commit/cf6c6a96498e6813e4b7ccaa56cacd9abefc332f))

# [7.0.0-beta.2](https://github.com/ForestAdmin/forest-rails/compare/v7.0.0-beta.1...v7.0.0-beta.2) (2021-06-07)


### Features

* **hooks:** developers can dynamically add or remove smart actions fields ([#465](https://github.com/ForestAdmin/forest-rails/issues/465)) ([970f3d8](https://github.com/ForestAdmin/forest-rails/commit/970f3d82806296137f2e64379c92884b04954580))


### BREAKING CHANGES

* **hooks:** fields parameters on hook function is no longer a map of field, it is now an array.
change hook is no longer choosen by the field name, field need to have hook defined inside it definition by addin a props hook.

# [6.5.0](https://github.com/ForestAdmin/forest-rails/compare/v6.4.1...v6.5.0) (2021-06-03)


### Features

* **schema:** move some meta data under stack attribute to prevent blocking scenarios on DWO ([#469](https://github.com/ForestAdmin/forest-rails/issues/469)) ([76aa754](https://github.com/ForestAdmin/forest-rails/commit/76aa7540300f75b0ea1d00ec3b60e4976b7d800e))

# [7.0.0-beta.1](https://github.com/ForestAdmin/forest-rails/compare/v6.4.1-beta.1...v7.0.0-beta.1) (2021-06-01)


### Bug Fixes

* **dependency:** now using forestadmin-jsonapi-serializers instead of the jsonapi-serializers gem ([#475](https://github.com/ForestAdmin/forest-rails/issues/475)) ([3feea36](https://github.com/ForestAdmin/forest-rails/commit/3feea36b3b578638f3ad7c16ebab8e457a68d71f))


### BREAKING CHANGES

* **dependency:** Switch from jsonapi-serializers to forestadmin-jsonapi-serializers to serialize data to the JSONAPI format, mainly to avoid conflict with the jsonapi-serializer library

## [6.4.1](https://github.com/ForestAdmin/forest-rails/compare/v6.4.0...v6.4.1) (2021-06-01)


### Bug Fixes

* fix time based graph when timezone is different with database ([#476](https://github.com/ForestAdmin/forest-rails/issues/476)) ([5d9fb89](https://github.com/ForestAdmin/forest-rails/commit/5d9fb8903ae53615dd1789bdebbc4d9c7d6f4576))

# [6.4.0](https://github.com/ForestAdmin/forest-rails/compare/v6.3.8...v6.4.0) (2021-05-26)


### Features

* **logger:** allow the logger to be configurable by the parent application ([#467](https://github.com/ForestAdmin/forest-rails/issues/467)) ([0bd355a](https://github.com/ForestAdmin/forest-rails/commit/0bd355ae6e52da33aa3a2988d48e958c400fb5f4))

## [6.3.8](https://github.com/ForestAdmin/forest-rails/compare/v6.3.7...v6.3.8) (2021-05-26)


### Bug Fixes

* **validation:** support multilines regex ([#466](https://github.com/ForestAdmin/forest-rails/issues/466)) ([1daf0b1](https://github.com/ForestAdmin/forest-rails/commit/1daf0b18e1757dd24e24b1cd2db759769a2daf1f))

## [6.3.7](https://github.com/ForestAdmin/forest-rails/compare/v6.3.6...v6.3.7) (2021-05-18)


### Bug Fixes

* **schema:** generate the schema properly on server start while using the classic Autoloader using Rails 5 ([#463](https://github.com/ForestAdmin/forest-rails/issues/463)) ([767236c](https://github.com/ForestAdmin/forest-rails/commit/767236c9a856709fc22d8f3b55f60e3384ec99d5))

## [6.3.6](https://github.com/ForestAdmin/forest-rails/compare/v6.3.5...v6.3.6) (2021-05-18)


### Bug Fixes

* fix timebased charts display with groupdate 5.2 and ruby 3.0 ([#462](https://github.com/ForestAdmin/forest-rails/issues/462)) ([ef64d9e](https://github.com/ForestAdmin/forest-rails/commit/ef64d9eedd4942dabd969ed1e139bba1f0d88b0e))

## [6.3.5](https://github.com/ForestAdmin/forest-rails/compare/v6.3.4...v6.3.5) (2021-05-12)


### Bug Fixes

* distribution charts using groupby on a relationship should not throws 403 Forbidden ([#459](https://github.com/ForestAdmin/forest-rails/issues/459)) ([50663e9](https://github.com/ForestAdmin/forest-rails/commit/50663e93083fc1b816b5fb56f8c0d049a9cec990))

## [6.3.4](https://github.com/ForestAdmin/forest-rails/compare/v6.3.3...v6.3.4) (2021-05-12)


### Bug Fixes

* **dependency:** ensure that project with a groupdate dependency >= 5 can install forest-rails ([#454](https://github.com/ForestAdmin/forest-rails/issues/454)) ([2c0a350](https://github.com/ForestAdmin/forest-rails/commit/2c0a3501a4a70319877bd1bd1bde970d10a86c9b))

## [6.3.3](https://github.com/ForestAdmin/forest-rails/compare/v6.3.2...v6.3.3) (2021-05-07)


### Bug Fixes

* allow actions hooks in production ([#455](https://github.com/ForestAdmin/forest-rails/issues/455)) ([39e976e](https://github.com/ForestAdmin/forest-rails/commit/39e976e550482f9c4f7da1c7facd11eb19ad499f))

## [6.3.2](https://github.com/ForestAdmin/forest-rails/compare/v6.3.1...v6.3.2) (2021-04-27)


### Bug Fixes

* **date-filter:** filtering only on hours now returns the expected records ([#449](https://github.com/ForestAdmin/forest-rails/issues/449)) ([aa02186](https://github.com/ForestAdmin/forest-rails/commit/aa021865df0309cb6a8894f501f267e29244cccf))

## [6.3.1](https://github.com/ForestAdmin/forest-rails/compare/v6.3.0...v6.3.1) (2021-04-13)


### Bug Fixes

* **authentication:** fix authentication errors after deploying a new instance with the same code (#gb01xz) ([#447](https://github.com/ForestAdmin/forest-rails/issues/447)) ([e2d1e37](https://github.com/ForestAdmin/forest-rails/commit/e2d1e374419fe7231374960e1cb279648b47882f)), closes [#gb01](https://github.com/ForestAdmin/forest-rails/issues/gb01)

# [6.3.0](https://github.com/ForestAdmin/forest-rails/compare/v6.2.3...v6.3.0) (2021-04-12)


### Features

* **smart-action:** handle isReadOnly field in smart action forms ([#442](https://github.com/ForestAdmin/forest-rails/issues/442)) ([835eab7](https://github.com/ForestAdmin/forest-rails/commit/835eab7176c652921e1df48418c97920c288e107))

## [6.2.3](https://github.com/ForestAdmin/forest-rails/compare/v6.2.2...v6.2.3) (2021-04-06)


### Bug Fixes

* **security:** patch marked dependency vulnerabilities ([#446](https://github.com/ForestAdmin/forest-rails/issues/446)) ([3a48d76](https://github.com/ForestAdmin/forest-rails/commit/3a48d76df19d1ec40542f882c935fee8675cc7e5))

## [6.2.2](https://github.com/ForestAdmin/forest-rails/compare/v6.2.1...v6.2.2) (2021-04-06)


### Bug Fixes

* **security:** patch y18n dependency vulnerabilities ([#445](https://github.com/ForestAdmin/forest-rails/issues/445)) ([9e10f7a](https://github.com/ForestAdmin/forest-rails/commit/9e10f7ae2db98a8c835f5fb548ea23d209fefe30))

## [6.2.1](https://github.com/ForestAdmin/forest-rails/compare/v6.2.0...v6.2.1) (2021-04-06)


### Bug Fixes

* **security:** patch ini dependency vulnerabilities ([#444](https://github.com/ForestAdmin/forest-rails/issues/444)) ([2e42eba](https://github.com/ForestAdmin/forest-rails/commit/2e42ebabb5e204bc8be4f7c662a96b2600ecac18))

# [6.2.0](https://github.com/ForestAdmin/forest-rails/compare/v6.1.1...v6.2.0) (2021-03-30)


### Features

* **filter:** add the possibility to filter on a smart field ([#410](https://github.com/ForestAdmin/forest-rails/issues/410)) ([00728be](https://github.com/ForestAdmin/forest-rails/commit/00728bedb5296ed2226c6eb94a6b4cb71758138c))

## [6.1.1](https://github.com/ForestAdmin/forest-rails/compare/v6.1.0...v6.1.1) (2021-03-22)


### Bug Fixes

* forest stats api 403 forbidden at chart creation ([#438](https://github.com/ForestAdmin/forest-rails/issues/438)) ([974a485](https://github.com/ForestAdmin/forest-rails/commit/974a485614221e7d460a9b23a97a5a7ab5f84f90))

# [6.1.0](https://github.com/ForestAdmin/forest-rails/compare/v6.0.5...v6.1.0) (2021-03-15)


### Features

* **security:** authorised only allowed stats queries using permissions ([#434](https://github.com/ForestAdmin/forest-rails/issues/434)) ([2014ab5](https://github.com/ForestAdmin/forest-rails/commit/2014ab5e4ef9365928f2a461ea19487c80558982))

## [6.0.5](https://github.com/ForestAdmin/forest-rails/compare/v6.0.4...v6.0.5) (2021-03-11)


### Bug Fixes

* **serurity:** decrease token expiration time to 1 hour ([c7a13c9](https://github.com/ForestAdmin/forest-rails/commit/c7a13c99ec3000aec5e081ffc271a4f169373b8e))

## [6.0.4](https://github.com/ForestAdmin/forest-rails/compare/v6.0.3...v6.0.4) (2021-03-09)


### Bug Fixes

* **authentication:** authentication error when the agent uses a prefix path in its url (#fb79c7) ([#436](https://github.com/ForestAdmin/forest-rails/issues/436)) ([0c6d46a](https://github.com/ForestAdmin/forest-rails/commit/0c6d46ae6817d14042320e5b4a38aaa2a2487d71)), closes [#fb79c7](https://github.com/ForestAdmin/forest-rails/issues/fb79c7)

## [6.0.3](https://github.com/ForestAdmin/forest-rails/compare/v6.0.2...v6.0.3) (2021-03-04)


### Bug Fixes

* **authentication:** safari cannot login on remote lianas because of third party cookies ([#435](https://github.com/ForestAdmin/forest-rails/issues/435)) ([033661f](https://github.com/ForestAdmin/forest-rails/commit/033661fc930b34da852e7a7720e621a8ebc9a9d8))

## [6.0.2](https://github.com/ForestAdmin/forest-rails/compare/v6.0.1...v6.0.2) (2021-03-04)


### Bug Fixes

* **authentication:** properly setup the session cookie to restore authentication on remote environments ([#433](https://github.com/ForestAdmin/forest-rails/issues/433)) ([556c56d](https://github.com/ForestAdmin/forest-rails/commit/556c56d37d0334464cb44c67ab91a21e191aa3a5))

## [6.0.1](https://github.com/ForestAdmin/forest-rails/compare/v6.0.0...v6.0.1) (2021-02-26)


### Bug Fixes

* **authentication:** add missing environment variable generation and check if caching is enabled (#epz6k0) ([#431](https://github.com/ForestAdmin/forest-rails/issues/431)) ([3fb83d1](https://github.com/ForestAdmin/forest-rails/commit/3fb83d17e2cfa8aa6148f90eba1f62748e938135)), closes [#epz6k0](https://github.com/ForestAdmin/forest-rails/issues/epz6k0)

# [6.0.0](https://github.com/ForestAdmin/forest-rails/compare/v5.4.4...v6.0.0) (2021-02-22)


### Bug Fixes

* **auth:** support multi-instances and remove auth's redirection ([#407](https://github.com/ForestAdmin/forest-rails/issues/407)) ([8fcf9d4](https://github.com/ForestAdmin/forest-rails/commit/8fcf9d4ba0f41b8c98451a3d15d31c73ab4fd162))
* **gemfile:** gemfile.lock forest_liana version mismatch ([#401](https://github.com/ForestAdmin/forest-rails/issues/401)) ([60ceaf1](https://github.com/ForestAdmin/forest-rails/commit/60ceaf195371c56ee327cffbd40e8b85bf42ea3a))


### Features

* **auth:** authenticate using oidc ([#383](https://github.com/ForestAdmin/forest-rails/issues/383)) ([b535ab4](https://github.com/ForestAdmin/forest-rails/commit/b535ab4e7e7e371c93d01bdb41c6006bd9acc7cd))
* **auth:** authenticate using oidc ([#400](https://github.com/ForestAdmin/forest-rails/issues/400)) ([4898b73](https://github.com/ForestAdmin/forest-rails/commit/4898b73bc70bf3a4828d7cdf63cd642add10b643))


### BREAKING CHANGES

* **auth:** Introduces a new authentication system.
- The application_url property is required to initialize ForestLiana,
- CORS rules must be adapted (to allow null origins).
* **auth:** New authentication system.
The application_url must be set in the ForestLiana initializer, adding a regex CORS rule for null origin is required.

## [5.4.4](https://github.com/ForestAdmin/forest-rails/compare/v5.4.3...v5.4.4) (2021-02-19)


### Bug Fixes

* display a warning on missing association ([#426](https://github.com/ForestAdmin/forest-rails/issues/426)) ([a4974a3](https://github.com/ForestAdmin/forest-rails/commit/a4974a33968eb3ec6574bf9fb0a0e59ca9b86b78))

## [5.4.3](https://github.com/ForestAdmin/forest-rails/compare/v5.4.2...v5.4.3) (2021-01-28)


### Bug Fixes

* use update instead of update_attribute to ensure rails 6.1 compatibility ([#417](https://github.com/ForestAdmin/forest-rails/issues/417)) ([41f9afb](https://github.com/ForestAdmin/forest-rails/commit/41f9afb8b2e45b2c26147f5f7bfe1941a38b3fd7))

## [5.4.2](https://github.com/ForestAdmin/forest-rails/compare/v5.4.1...v5.4.2) (2021-01-27)


### Bug Fixes

* **stripe:** fix serialization issues on invoices ([#412](https://github.com/ForestAdmin/forest-rails/issues/412)) ([d9595bf](https://github.com/ForestAdmin/forest-rails/commit/d9595bfc79a46a9471f87154a023e35c4fd7d423))

## [5.4.1](https://github.com/ForestAdmin/forest-rails/compare/v5.4.0...v5.4.1) (2021-01-21)


### Bug Fixes

* **smart-action-hook:** value injected to an enum field of type is now correctly handled ([#414](https://github.com/ForestAdmin/forest-rails/issues/414)) ([ef90105](https://github.com/ForestAdmin/forest-rails/commit/ef90105659f57c4c8531b0c4d576f345bc976b33))

# [6.0.0-beta.4](https://github.com/ForestAdmin/forest-rails/compare/v6.0.0-beta.3...v6.0.0-beta.4) (2021-01-15)


### Bug Fixes

* **auth:** support multi-instances and remove auth's redirection ([#407](https://github.com/ForestAdmin/forest-rails/issues/407)) ([8fcf9d4](https://github.com/ForestAdmin/forest-rails/commit/8fcf9d4ba0f41b8c98451a3d15d31c73ab4fd162))

# [6.0.0-beta.3](https://github.com/ForestAdmin/forest-rails/compare/v6.0.0-beta.2...v6.0.0-beta.3) (2020-12-14)


### Bug Fixes

* fix test after enums ([#398](https://github.com/ForestAdmin/forest-rails/issues/398)) ([7b37350](https://github.com/ForestAdmin/forest-rails/commit/7b37350fc2b6244c3180cb953c2954d5b6927739))
* **smart-actions:** reset value when not present in enums in hook response ([#397](https://github.com/ForestAdmin/forest-rails/issues/397)) ([a1ddac1](https://github.com/ForestAdmin/forest-rails/commit/a1ddac1c0d474e11b43e0f489dcc5ea70cd940b8))
* **smart-actions:** transform legacy widgets in hooks ([#395](https://github.com/ForestAdmin/forest-rails/issues/395)) ([0183d08](https://github.com/ForestAdmin/forest-rails/commit/0183d0883c85fa2569cba70d268747536770a612))
* **smart-actions:** use changedField instead of comparing values to trigger the correct change hook ([#396](https://github.com/ForestAdmin/forest-rails/issues/396)) ([d65c065](https://github.com/ForestAdmin/forest-rails/commit/d65c065319f9ab83d909214a2a71923467a78a0d))


### Features

* **role:** add support for new roles ACL permissions ([#391](https://github.com/ForestAdmin/forest-rails/issues/391)) ([ae3539e](https://github.com/ForestAdmin/forest-rails/commit/ae3539e59c49b525078639a6d316ae2b5598ed75))
* handle hooks ([#382](https://github.com/ForestAdmin/forest-rails/issues/382)) ([8dd0e35](https://github.com/ForestAdmin/forest-rails/commit/8dd0e356be27b33379b2aaa0376deb3a76123300))

# [5.4.0](https://github.com/ForestAdmin/forest-rails/compare/v5.3.3...v5.4.0) (2020-12-10)


### Features

* **role:** add support for new roles ACL permissions ([#391](https://github.com/ForestAdmin/forest-rails/issues/391)) ([ae3539e](https://github.com/ForestAdmin/forest-rails/commit/ae3539e59c49b525078639a6d316ae2b5598ed75))

# [6.0.0-beta.2](https://github.com/ForestAdmin/forest-rails/compare/v6.0.0-beta.1...v6.0.0-beta.2) (2020-12-09)


### Bug Fixes

* **gemfile:** gemfile.lock forest_liana version mismatch ([#401](https://github.com/ForestAdmin/forest-rails/issues/401)) ([60ceaf1](https://github.com/ForestAdmin/forest-rails/commit/60ceaf195371c56ee327cffbd40e8b85bf42ea3a))


### Features

* **auth:** authenticate using oidc ([#400](https://github.com/ForestAdmin/forest-rails/issues/400)) ([4898b73](https://github.com/ForestAdmin/forest-rails/commit/4898b73bc70bf3a4828d7cdf63cd642add10b643))


### BREAKING CHANGES

* **auth:** Introduces a new authentication system.
- The application_url property is required to initialize ForestLiana,
- CORS rules must be adapted (to allow null origins).

# [6.0.0-beta.1](https://github.com/ForestAdmin/forest-rails/compare/v5.2.3...v6.0.0-beta.1) (2020-12-09)


### Features

* **auth:** authenticate using oidc ([#383](https://github.com/ForestAdmin/forest-rails/issues/383)) ([b535ab4](https://github.com/ForestAdmin/forest-rails/commit/b535ab4e7e7e371c93d01bdb41c6006bd9acc7cd))


### BREAKING CHANGES

* **auth:** New authentication system.
The application_url must be set in the ForestLiana initializer, adding a regex CORS rule for null origin is required.

## [5.3.3](https://github.com/ForestAdmin/forest-rails/compare/v5.3.2...v5.3.3) (2020-12-08)


### Bug Fixes

* fix test after enums ([#398](https://github.com/ForestAdmin/forest-rails/issues/398)) ([7b37350](https://github.com/ForestAdmin/forest-rails/commit/7b37350fc2b6244c3180cb953c2954d5b6927739))
* **smart-actions:** reset value when not present in enums in hook response ([#397](https://github.com/ForestAdmin/forest-rails/issues/397)) ([a1ddac1](https://github.com/ForestAdmin/forest-rails/commit/a1ddac1c0d474e11b43e0f489dcc5ea70cd940b8))

## [5.3.2](https://github.com/ForestAdmin/forest-rails/compare/v5.3.1...v5.3.2) (2020-12-07)


### Bug Fixes

* **smart-actions:** use changedField instead of comparing values to trigger the correct change hook ([#396](https://github.com/ForestAdmin/forest-rails/issues/396)) ([d65c065](https://github.com/ForestAdmin/forest-rails/commit/d65c065319f9ab83d909214a2a71923467a78a0d))

## [5.3.1](https://github.com/ForestAdmin/forest-rails/compare/v5.3.0...v5.3.1) (2020-12-07)


### Bug Fixes

* **smart-actions:** transform legacy widgets in hooks ([#395](https://github.com/ForestAdmin/forest-rails/issues/395)) ([0183d08](https://github.com/ForestAdmin/forest-rails/commit/0183d0883c85fa2569cba70d268747536770a612))

# [5.3.0](https://github.com/ForestAdmin/forest-rails/compare/v5.2.3...v5.3.0) (2020-12-07)


### Features

* handle hooks ([#382](https://github.com/ForestAdmin/forest-rails/issues/382)) ([8dd0e35](https://github.com/ForestAdmin/forest-rails/commit/8dd0e356be27b33379b2aaa0376deb3a76123300))

## [5.2.3](https://github.com/ForestAdmin/forest-rails/compare/v5.2.2...v5.2.3) (2020-12-02)


### Bug Fixes

* **filter:** fix filtering with projects on Rails 5.1 ([#381](https://github.com/ForestAdmin/forest-rails/issues/381)) ([4f86990](https://github.com/ForestAdmin/forest-rails/commit/4f8699006a2836b8baa631d38d0e3532ec6ea198))

## [5.2.2](https://github.com/ForestAdmin/forest-rails/compare/v5.2.1...v5.2.2) (2020-08-04)


### Bug Fixes

* **vulnerability:** patch a potential vulnerability updating lodash dependency ([#372](https://github.com/ForestAdmin/forest-rails/issues/372)) ([5bd2471](https://github.com/ForestAdmin/forest-rails/commit/5bd2471ef1fad8f6325816a5f1c682dbce9eee29))

## [5.2.1](https://github.com/ForestAdmin/forest-rails/compare/v5.2.0...v5.2.1) (2020-07-13)


### Bug Fixes

* **vulnerabilities:** bump 2 dependencies of dependencies ([#368](https://github.com/ForestAdmin/forest-rails/issues/368)) ([7e63f70](https://github.com/ForestAdmin/forest-rails/commit/7e63f707266cc016b0ddab123336b1215635816d))

# [5.2.0](https://github.com/ForestAdmin/forest-rails/compare/v5.1.3...v5.2.0) (2020-06-02)


### Features

* **scope:** validate scope context on list/count request ([#361](https://github.com/ForestAdmin/forest-rails/issues/361)) ([df502e1](https://github.com/ForestAdmin/forest-rails/commit/df502e1f164985e86f8145b52a796948d3c483ad))

## [5.1.3](https://github.com/ForestAdmin/forest-rails/compare/v5.1.2...v5.1.3) (2020-05-19)


### Bug Fixes

* **release:** fix the automatic release using the ci ([037c651](https://github.com/ForestAdmin/forest-rails/commit/037c6516fbdde7127b08d3ab602e06e30f96e5c0))

## RELEASE 5.1.2 - 2020-05-12
### Changed
- Technical - Patch CI configuration warnings.
- Readme - Update the community badge.
- Readme - Fix interface screenshots display.
- Readme - Update and re-position the "How it works" section.

## RELEASE 5.1.1 - 2020-04-20
### Fixed
- Charts - Ensure that line charts are well displayed in projects having a `groupdate` dependency version 5.X.

## RELEASE 5.1.0 - 2020-04-17
### Added
- Smart Action - Allow users to protect their smart-action APIs from unauthorized usage.

### Changed
- Technical - Introduce conventional commits.
- Technical - Adapt release script to conventional commits.

### Fixed
- Technical - Fix the license type in the `package.json` file.
- Wording - Fix a typo in the missing .forestadmin-schema.json file message.

## RELEASE 5.0.0 - 2020-03-20

## RELEASE 5.0.0-beta.0 - 2020-03-03
### Added
- Resources Getter - Add a get_ids_from_request method to get all models IDs given a query or an ID list.
- Resource Deletion - Users can now bulk delete records.

### Fixed
- Has Many Relationships - Fix records count, i.e consider filters when counting.

## RELEASE 4.2.0 - 2020-01-22
### Added
- Has Many Relationships - Enable sorting on belongsTo relationship columns in related data.

### Fixed
- Technical - Fix CI build.

## RELEASE 4.1.3 - 2019-12-04
### Fixed
- Stripe Integration - Fix Stripe collections display with latest Stripe gem versions.

## RELEASE 4.1.2 - 2019-11-15
### Fixed
- Technical - Fix CI error.
- Filters - Prevent a potential error if a client request resources with a blank filter query parameter.
- Readme - Fix the build badge display.
- Serializers - Prevent unexpected serializers removal.

## RELEASE 4.1.1 - 2019-10-23
### Fixed
- Records list - Fix records retrieval issues. [Regression introduced in 4.0.1]
- Technical - Fix CI error.

## RELEASE 4.1.0 - 2019-10-21
### Added
- Rails Versions - Support Rails 6 projects.

## RELEASE 4.0.2 - 2019-10-18
### Fixed
- Validation - Do not add non-generic validations to fields schema (for validations using `on:` option).

## RELEASE 4.0.1 - 2019-10-18
### Fixed
- Technical - Fix a class name typo.
- Logs - Prevent "already initialized constant" warnings due to multiple serializer definition.

## RELEASE 4.0.0 - 2019-10-04

## RELEASE 4.0.0-beta.1 - 2019-09-19
### Added
- Configurations - Users can specify the directory for Forest Smart Implementation.
- DevOps - Automatically send the release note on Slack after a release.

### Changed
- Readme - Add a community section.
- Readme - Remove the Licence section as it is already accessible in the Github page header.

## RELEASE 4.0.0-beta.0 - 2019-08-07
### Changed
- Technical - Makes the JWT lighter and consistent across lianas.
- Filters - Support complex/generic conditions chaining. 🛡
- Technical - Upgrade Ruby version to 2.3.4 for the CI.

## RELEASE 3.3.0 - 2019-09-19
### Added
- Configurations - Users can specify the directory for Forest Smart Implementation.
- DevOps - Automatically send the release note on Slack after a release.

### Changed
- Readme - Add a community section.
- Readme - Remove the Licence section as it is already accessible in the Github page header.

## RELEASE 3.2.0 - 2019-07-22
### Added
- Column Types - Support HSTORE column type.

## RELEASE 3.1.1 - 2019-07-18
### Fixed
- Fields - Detect properly `date` type columns to provide the right date picker experience in the UI.

## RELEASE 3.1.0 - 2019-07-09
### Added
- Filters - Support 'OR' filters with conditions on references.

## RELEASE 3.0.7 - 2019-06-20
### Fixed
- Schema - Schemas having fields with validations based on complex regex are now properly sent in remote environments.

## RELEASE 3.0.6 - 2019-06-18
### Changed
- Security - Remove unnecessary leeway of 30s on JWTs.

### Fixed
- Schema - Fix potential server crash on start due schema formatting internal error.

## RELEASE 3.0.5 - 2019-06-13
### Fixed
- Export - Fix broken export action from related data. [Regression introduced in 2.15.1]

## RELEASE 3.0.4 - 2019-05-21
### Fixed
- Record Update - Prevent `encrypted_password` removal on Devise users models update.

## RELEASE 3.0.3 - 2019-05-15
### Fixed
- Exports - Fix broken exports if users restart a new browser session (ie quit/restart browser).

## RELEASE 3.0.2 - 2019-05-10
### Fixed
- Smart Actions - Fix broken Smart Actions having a name containing emoji without custom endpoint.

## RELEASE 3.0.1 - 2019-04-29
### Fixed
- Smart Actions - Fix crash on server start.

## RELEASE 3.0.0 - 2019-04-22

## RELEASE 3.0.0-beta.18 - 2019-04-10
### Fixed
- Search - Enable PostgreSQL's CITEXT fields in search.

## RELEASE 3.0.0-beta.17 - 2019-04-04
### Changed
- Error Handling - Display an explicit error message if the envSecret is detected as missing or unknown during data a API request.

## RELEASE 3.0.0-beta.16 - 2019-03-29
### Fixed
- Security - Fix implementation of session token passed in headers while downloading collections records.

## RELEASE 3.0.0-beta.15 - 2019-03-27
### Changed
- Security - Do not pass session token in query params while downloading collections records.

## RELEASE 3.0.0-beta.14 - 2019-03-01
### Fixed
- Records Display - Restrict record data serialization based the schema collection fields in the #create and #update actions.

## RELEASE 3.0.0-beta.13 - 2019-02-28
### Fixed
- Records Display - Restrict record data serialization based the schema collection fields in the #show action.

## RELEASE 3.0.0-beta.12 - 2019-02-28
### Fixed
- Records Display - Ensure that the data is properly sent even if an attribute serialization happens for an unknown reason.

## RELEASE 3.0.0-beta.11 - 2019-02-27
### Fixed
- Filters - Fix resources display if filtered with associations conditions with the related columns hidden in the list. 🛡

## RELEASE 3.0.0-beta.10 - 2019-02-26
### Fixed
- Schema - Ensure that unhandled field types are not defined anymore in collections schemas. 🛡

## RELEASE 3.0.0-beta.9 - 2019-02-25
### Fixed
- Charts - Fix Value charts having filters on associations targeting a collection having with a custom table name. 🛡
- Charts - Fix Value charts having filters on associations targeting a collection associated through multiple `belongs_to` association to the current resource. 🛡

## RELEASE 3.0.0-beta.8 - 2019-02-20
### Fixed
- Export - Fix broken export action. [Regression introduced in 3.0.0-beta.7]

## RELEASE 3.0.0-beta.7 - 2019-02-06
### Fixed
- Filters - Fix association filtering on collections having several associations targeting the same table.

## RELEASE 3.0.0-beta.6 - 2019-02-01
### Added
- Charts - Users can create "Leaderboard" charts.
- Charts - Users can create "Objective" charts.
- Technical - Add a new apimap property "relationship".

## RELEASE 3.0.0-beta.5 - 2019-01-30
### Fixed
- Validations - Remove badly set validations on Array fields.

## RELEASE 3.0.0-beta.4 - 2019-01-30
### Fixed
- Schema - Fix empty validations set in the schema file.

## RELEASE 3.0.0-beta.3 - 2019-01-30
### Fixed
- Build - Fix liana version set in the `.forestadmin-schema.json` meta.

## RELEASE 3.0.0-beta.2 - 2019-01-30
### Fixed
- Build - Fix liana version set in the `.forestadmin-schema.json` meta.

## RELEASE 3.0.0-beta.1 - 2019-01-30
### Fixed
- Build - Fix regressions in the build script.

## RELEASE 3.0.0-beta.0 - 2019-01-30
### Added
- Developer Experience - On start, create a `.forestadmin-schema.json` file that contains the schema definition.
- Developer Experience - On production, load `.forestadmin-schema.json` for schema update.

### Changed
- Schema - Developers can deactivate the automatic schema sending on server start (using `FOREST_DISABLE_AUTO_SCHEMA_APPLY` environment variable, deprecating `FOREST_DEACTIVATE_AUTOMATIC_APIMAP`).

## RELEASE 2.15.8 - 2019-03-01
### Fixed
- Records Display - Restrict record data serialization based the schema collection fields in the #create and #update actions.

## RELEASE 2.15.7 - 2019-02-28
### Fixed
- Records Display - Restrict record data serialization based the schema collection fields in the #show action.

## RELEASE 2.15.6 - 2019-02-28
### Fixed
- Records Display - Ensure that the data is properly sent even if an attribute serialization happens for an unknown reason.

## RELEASE 2.15.5 - 2019-02-27
### Fixed
- Filters - Fix resources display if filtered with associations conditions with the related columns hidden in the list. 🛡

## RELEASE 2.15.4 - 2019-02-26
### Fixed
- Schema - Ensure that unhandled field types are not defined anymore in collections schemas. 🛡

## RELEASE 2.15.3 - 2019-02-25
### Fixed
- Charts - Fix Value charts having filters on associations targeting a collection having with a custom table name. 🛡
- Charts - Fix Value charts having filters on associations targeting a collection associated through multiple `belongs_to` association to the current resource. 🛡

## RELEASE 2.15.2 - 2019-02-20
### Fixed
- Export - Fix broken export action. [Regression introduced in 2.15.1]

## RELEASE 2.15.1 - 2019-02-06
### Fixed
- Filters - Fix association filtering on collections having several associations targeting the same table.

## RELEASE 2.15.0 - 2019-02-01
### Added
- Charts - Users can create "Leaderboard" charts.
- Charts - Users can create "Objective" charts.
- Technical - Add a new apimap property "relationship".

## RELEASE 2.14.7 - 2019-01-30
### Added
- Build - Tag versions on git for each release.
- Build - Developers can now create beta versions.

### Fixed
- Validations - Remove badly set validations on Array fields.

## RELEASE 2.14.6 - 2018-12-14
### Changed
- Error Logging - Improve routing error logs for some edge cases.

## RELEASE 2.14.5 - 2018-12-06
### Fixed
- Initialization - Fix `included_models` and `excluded_models` options.

## RELEASE 2.14.4 - 2018-11-12
### Fixed
- Models - Fix models having a table name being a reserved SQL word.

## RELEASE 2.14.3 - 2018-11-02
### Fixed
- Records List - Fix filtering on the records list. [Regression introduced in 2.14.2]
- Security - Upgrade sprockets dependency version to fix a known vulnerability.

## RELEASE 2.14.2 - 2018-10-31
### Fixed
- Records List - Avoid crash when filtering on a bad association or a bad field in resource getter.

## RELEASE 2.14.1 - 2018-10-30
### Fixed
- API - Fix API crashes due to bad Forest API initialization if `FOREST_DEACTIVATE_AUTOMATIC_APIMAP` is configured.
- Apimap - Fix the Apimap info sent with the `forest:display_apimap` task.

## RELEASE 2.14.0 - 2018-10-25
### Added
- Apimap - Developers can deactivate the automatic Apimap sending on server start (using `FOREST_DEACTIVATE_AUTOMATIC_APIMAP` environment variable).
- Apimap - Add a `forest:display_apimap` rake task to manually inspect the current Apimap version.
- Apimap - Add a `forest:send_apimap` rake task to manually synchonize the models/customization with Forest servers.

### Change
- Technical - Remove a useless query param in the authorizations request.
- Technical - Simplify the Bootstrapper initialize signature.

## RELEASE 2.13.7 - 2018-10-19
### Fixed
- Filters - Fix BelongsTo filters on a destination table having a "non conventional" singular name. [Regression introduced in 2.8.5]

## RELEASE 2.13.6 - 2018-10-18
### Fixed
- Live Query - Trim whitespaces in all queries and subqueries to avoid errors.

## RELEASE 2.13.5 - 2018-10-12
### Fixed
- Live Query Segment - Optimize resource retrieving to avoid using too much memory.

## RELEASE 2.13.4 - 2018-10-03
### Fixed
- Segment - Return an error 404 instead of 500 when a collection with an incorrect segment is called.

## RELEASE 2.13.3 - 2018-09-25
### Fixed
- Permissions - Fix potential bad forbidden responses on first requests after server start.

## RELEASE 2.13.2 - 2018-09-24
### Fixed
- Authentication - Fix authentication for projects using Ruby 2.2.X.

## RELEASE 2.13.1 - 2018-09-19
### Fixed
- Development Autoreload - Prevent "A copy of ForestLiana::BaseController has been removed from the module tree but is still active!" in development mode.

## RELEASE 2.13.0 - 2018-09-13
### Added
- IP Whitelist - Add IP Whitelist feature.

## RELEASE 2.12.0 - 2018-09-13
### Added
- Authentication - Add two factor authentication.

## RELEASE 2.11.13 - 2018-09-11
### Added
- Logs - Display an error log (and stacktrace) in case of routing error.

## RELEASE 2.11.12 - 2018-09-10
### Fixed
- Logs - Display an error log (and stacktrace) in case of NoMethodError in the find_resource before_filter.

## RELEASE 2.11.11 - 2018-08-30
### Changed
- Records Deletion - The deletion of a record which has already been deleted does not display an error anymore.

## RELEASE 2.11.10 - 2018-08-23
### Changed
- STI Models - Display a warning on server start for any STI parent models that do not have children.

### Fixed
- [BREAKING] Collections - Fixes potential behaviour issues of collections having a name that collides with query params keys (searches, pages, sorts, timezones,...).
  The smart actions params are retrieved differently:
  *old* --> `params[:income][:data][:attributes][:values][:amount]`
  *new* --> `params[:data][:attributes][:values][:amount]`

- STI Models - Make the field corresponding to the inheritance_column (`type` by default) accessible to STI parent models that don't have children.

## RELEASE 2.11.9 - 2018-08-10
### Fixed
- Gems Support - Improve ActiveType::Object detection to ignore it.

## RELEASE 2.11.8 - 2018-08-10
### Fixed
- Gems Support - Ignores ActiveType::Object association during introspection and interactions (https://github.com/makandra/active_type).

## RELEASE 2.11.7 - 2018-08-10
### Fixed
- Records Details - Fix record details display. [Regression introduced in 2.11.6]

## RELEASE 2.11.6 - 2018-08-09
### Fixed
- Smart BelongsTo - Fix records list retrieval if the collection contains a Smart BelongsTo column that has been hidden. [Regression introduced in 2.9.1]

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
