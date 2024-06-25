define rabbitmq::management_exange(
    Enum['present','absent']    $ensure     = present
) {
    case $ensure {
        present: {
        }
        absent: {
        }
        default: {
            fail('Unknown ensure: $ensure, must be present or absent')
        }
    }
}
