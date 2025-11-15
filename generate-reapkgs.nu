#!/usr/bin/env nu

let type_to_path = {
    script: "Scripts",
    effect: "Effects",
    data: "Data",
    extension: "UserPlugins",
    theme: "ColorThemes",
    langpack: "LangPack",
    "web-interface": "reaper_www_root",
    "project-template": "ProjectTemplates",
    "track-template": "TrackTemplates",
    "midi-note-names": "MIDINoteNames",
    "automation-item": "AutomationItems"
}

let raw_index = http get https://github.com/JoepVanlier/JSFX/raw/master/index.xml

let index_name = $raw_index.attributes.name

let index_packages = $raw_index.content | par-each { |raw_category|
  let category_name = $raw_category | get -i attributes.name
  $raw_category.content | par-each { |raw_package|
    let type = $raw_package | get -i attributes.type
    let versions = $raw_package | get content | where tag == version | par-each { |raw_version|
      let files = $raw_version | get content | where tag == source | par-each { |raw_source|
        let raw_explicit_path = $raw_source | get -i attributes.file
        let url = $raw_source | get -i content.content.0

        let relative_path = if $raw_explicit_path == null {
          $url | path basename | url decode
        } else {
          $raw_explicit_path
        }

        let parent_dir = if $type in ["script", "effect", "automation-item"] {
          $"($type_to_path | get $type)/($index_name)/($category_name)"
        } else {
          $type_to_path | get $type
        }

        let joined_path = $parent_dir | path join $relative_path

        let redirected_url = curl -w "%{url_effective}" -I -L -s -S -o /dev/null $url | str trim
        let sanitized_name = $url | url parse | get path | path basename | url decode | str replace -r -a '[^-.+_?=0-9a-zA-Z]' '-'
        let sha256 = nix-prefetch-url $redirected_url --name $sanitized_name | str trim

        {
          path: $joined_path,
          url: $url,
          sha256: $sha256
        }
      }
      {
        name: ($raw_version | get -i attributes.name),
        time: ($raw_version | get attributes.time | into datetime),
        author: ($raw_version | get -i attributes.author),
        files: $files
      }
    } | sort-by --reverse time
    {
      name: ($raw_package | get -i attributes.name),
      type: $type,
      category: $category_name,
      description: ($raw_package | get -i attributes.desc),
      versions: $versions
      latest-version: $versions.0
    }
  }
} | flatten

$index_packages | explore
