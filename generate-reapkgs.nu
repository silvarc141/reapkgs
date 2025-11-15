#!/usr/bin/env nu

let raw_index = http get https://github.com/JoepVanlier/JSFX/raw/master/index.xml

let index_name = $raw_index.attributes.name

let index_packages = $raw_index.content | each { |raw_category|
  let category_name = $raw_category | get -i attributes.name
  $raw_category.content | each { |raw_package|
    let versions = $raw_package | get content | where tag == version | each { |raw_version|
      let files = $raw_version | get content | where tag == source | each { |raw_source|
        {
          name: ($raw_source | get -i attributes.file),
          url: ($raw_source | get -i content.content.0)
        }
      }
      {
        name: ($raw_version | get -i attributes.name),
        time: ($raw_version | get attributes.time | into datetime),
        author: ($raw_version | get -i attributes.author),
        files: $files
      }
    }
    {
      name: ($raw_package | get -i attributes.name),
      type: ($raw_package | get -i attributes.type),
      category: $category_name,
      description: ($raw_package | get -i attributes.desc),
      versions: $versions
    }
  }
} | flatten

$index_packages | explore
