let plugin_dir = ($nu.current-exe | path dirname)

for plugin in [
    "nu_plugin_custom_values.exe"
    "nu_plugin_example.exe"
    "nu_plugin_formats.exe"
    "nu_plugin_gstat.exe"
    "nu_plugin_inc.exe"
    "nu_plugin_polars.exe"
    "nu_plugin_query.exe"
    "nu_plugin_stress_internals.exe"
] {
    let plugin_path = [$plugin_dir $plugin] | path join
    if ($plugin_path | path exists) {
        plugin add $plugin_path
    } else {
        print $"Skipping missing plugin: ($plugin_path)"
    }
}
