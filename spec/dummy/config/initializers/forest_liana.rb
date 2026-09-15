ForestLiana.env_secret = 'env_secret_test'
ForestLiana.auth_secret = 'auth_secret_test'
ForestLiana.application_url = 'http://localhost:3000'
ForestLiana.workflow_executor_url = 'http://workflow-executor.test:4001'
# acts_as_taggable_on's own tables, not Forest collections — keep them out of the apimap and out
# of ForestLiana.models the same way any other internal join model would be. ForestLiana.name_for
# replaces '::' with '__', so the namespaced class name has to be pre-mangled to match here too.
ForestLiana.excluded_models = %w[ActsAsTaggableOn__Tag ActsAsTaggableOn__Tagging]
