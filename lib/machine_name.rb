# key work_machine_name can only be 255 UTF8 characters, irrespective of the actual length
# as this is a limitation of MySQL.
# also increased sort_name to 765 chars.
module MachineName
  module_function
  #Machine name is a string with:
  #  1. all punctuation/spaces converted to single space
  #  2. stripped of leading/trailing spaces and downcased
  def make_machine_name(string)
    #string.gsub(/[\W]+/, " ").strip.downcase
    # actually next is same as above 
    string.gsub(/[\W]+/, " ").gsub(/[,.]/, " ").strip.downcase
  end

  def make_machine_name_from_array(array_of_strings)
    make_machine_name(array_of_strings.join(" "))
  end

end

module MachineNameUpdater
  include MachineName
  def update_machine_name(force = false)
    if self.attribute_changed?(:name) or self.saved_change_to_attribute?(:name) or force
      self.machine_name = make_machine_name(self.name)
    end
  end
end