class example {
  $enabled = defined(Class['synthetic'])
  notice($enabled, template('example/state.erb'))
}
