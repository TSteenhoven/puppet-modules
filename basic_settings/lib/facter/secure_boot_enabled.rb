# frozen_string_literal: true

Facter.add('secure_boot_enabled') do
  confine kernel: 'Linux' # Only for Linux-systemen
  setcode do
    secure_boot_path = '/sys/firmware/efi/efivars/SecureBoot-*'
    if Dir.glob(secure_boot_path).any?
      # Check if we can reade secure bootfile
      secure_boot_value = File.read(Dir.glob(secure_boot_path).first).unpack('C*').last
      secure_boot_value == 1 # Secure Boot is enabled and the value is 1
    else
      false # No Secure Boot
    end
  end
end
