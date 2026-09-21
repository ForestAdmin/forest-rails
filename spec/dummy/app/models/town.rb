class Town < Location
  # Deliberately redefines its parent's `island` with a scope of its own: same name, different
  # reflection, the shape an STI subclass narrowing an inherited association takes. The fixture
  # for "a cached association the two classes do not define identically must not cross becomes()"
  # (spec/requests/sti_record_conversion_spec.rb).
  belongs_to :island, -> { where(name: 'nowhere') }, optional: true
end
