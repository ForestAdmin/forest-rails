class Forest::Product
  include ForestLiana::Collection

  collection :Product, countable: false
end
