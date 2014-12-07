#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef-dk/exceptions'
require 'chef-dk/cookbook_metadata'
require 'chef-dk/ui'
require 'chef/util/path_helper'
require 'chef/json_compat'

module ChefDK
  module Policyfile
    class ChefRepoCookbookSource

      attr_reader :path
      attr_accessor :ui

      def initialize(path)
        @path = path
        @ui = UI.new
      end

      def ==(other)
        other.kind_of?(self.class) && other.path = path
      end

      def universe_graph
        slurp_metadata! if @universe_graph.nil?
        @universe_graph
      end

      def source_options_for(cookbook_name, cookbook_version)
        { path: cookbook_version_paths[cookbook_name][cookbook_version], version: cookbook_version }
      end

      private

      def cookbook_version_paths
        slurp_metadata! if @cookbook_version_paths.nil?
        @cookbook_version_paths
      end

      def slurp_metadata!
          begin
            @universe_graph = {}
            @cookbook_version_paths = {}
            Dir.glob(File.join(Chef::Util::PathHelper.escape_glob(path), '*')).each do |cookbook|
              next unless File.directory?(cookbook)
              next if cookbook == '.' || cookbook == '..'
              metadata = CookbookMetadata.new
              metadata_rb = File.join(cookbook, 'metadata.rb')
              metadata_json = File.join(cookbook, 'metadata.json')
              if File.exist?(metadata_json)
                data = Chef::JSONCompat.parse(IO.read(metadata_json))
                metadata.from_hash(data['metadata'])
              elsif File.exist?(metadata_rb)
                metadata.from_file(metadata_rb)
              else
                ui.err("WARN: found cookbook in chef-repo with no metadata: #{File.basename(cookbook)}, skipping")
                next
              end
              @universe_graph[metadata.cookbook_name] ||= {}
              @universe_graph[metadata.cookbook_name][metadata.version] = metadata.dependencies.to_a
              @cookbook_version_paths[metadata.cookbook_name] ||= {}
              @cookbook_version_paths[metadata.cookbook_name][metadata.version] = cookbook
            end
          end
      end

    end
  end
end
