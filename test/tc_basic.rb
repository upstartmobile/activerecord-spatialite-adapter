# -----------------------------------------------------------------------------
#
# Tests for the MysqlSpatial ActiveRecord adapter
#
# -----------------------------------------------------------------------------
# Copyright 2010 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# -----------------------------------------------------------------------------
;

require 'test/unit'
require 'rgeo/active_record/adapter_test_helper'

module RGeo
  module ActiveRecord  # :nodoc:
    module SpatiaLiteAdapter  # :nodoc:
      module Tests  # :nodoc:

        class TestBasic < ::Test::Unit::TestCase  # :nodoc:


          DATABASE_CONFIG_PATH = ::File.dirname(__FILE__)+'/database.yml'

          def self.before_open_database(params_)
            params_[:config].symbolize_keys!
            database_ = params_[:config][:database]
            dir_ = ::File.dirname(database_)
            ::FileUtils.mkdir_p(dir_) unless dir_ == '.'
            ::FileUtils.rm_f(database_)
          end

          def self.initialize_database(params_)
            params_[:connection].execute('SELECT InitSpatialMetaData()')
          end

          include AdapterTestHelper


          define_test_methods do


            def populate_ar_class(content_)
              klass_ = create_ar_class
              case content_
              when :latlon_point
                klass_.connection.create_table(:spatial_test) do |t_|
                  t_.column 'latlon', :point, :srid => 3785
                end
              end
              klass_
            end


            def test_version
              assert_not_nil(::ActiveRecord::ConnectionAdapters::SpatiaLiteAdapter::VERSION)
            end


            def test_meta_data_present
              result_ = DEFAULT_AR_CLASS.connection.select_value("SELECT COUNT(*) FROM spatial_ref_sys").to_i
              assert_not_equal(0, result_)
            end


            def test_create_simple_geometry
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.column 'latlon', :geometry
              end
              assert_equal(1, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
              assert_equal(::RGeo::Feature::Geometry, klass_.columns.last.geometric_type)
              assert(klass_.cached_attributes.include?('latlon'))
              klass_.connection.drop_table(:spatial_test)
              assert_equal(0, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
            end


            def test_create_point_geometry
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.column 'latlon', :point
              end
              assert_equal(::RGeo::Feature::Point, klass_.columns.last.geometric_type)
              assert(klass_.cached_attributes.include?('latlon'))
            end


            def test_create_geometry_with_index
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.column 'latlon', :geometry
              end
              klass_.connection.change_table(:spatial_test) do |t_|
                t_.index([:latlon], :spatial => true)
              end
              assert(klass_.connection.indexes(:spatial_test).last.spatial)
              assert_equal(1, klass_.connection.select_value("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='idx_spatial_test_latlon'").to_i)
              klass_.connection.drop_table(:spatial_test)
              assert_equal(0, klass_.connection.select_value("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='idx_spatial_test_latlon'").to_i)
            end


            def test_set_and_get_point
              klass_ = populate_ar_class(:latlon_point)
              obj_ = klass_.new
              assert_nil(obj_.latlon)
              obj_.latlon = @factory.point(1, 2)
              assert_equal(@factory.point(1, 2), obj_.latlon)
              assert_equal(3785, obj_.latlon.srid)
            end


            def test_set_and_get_point_from_wkt
              klass_ = populate_ar_class(:latlon_point)
              obj_ = klass_.new
              assert_nil(obj_.latlon)
              obj_.latlon = 'POINT(1 2)'
              assert_equal(@factory.point(1, 2), obj_.latlon)
              assert_equal(3785, obj_.latlon.srid)
            end


if false
            def test_save_and_load_point
              klass_ = populate_ar_class(:latlon_point)
              obj_ = klass_.new
              obj_.latlon = @factory.point(1, 2)
              obj_.save!
              id_ = obj_.id
              obj2_ = klass_.find(id_)
              assert_equal(@factory.point(1, 2), obj2_.latlon)
              assert_equal(3785, obj2_.latlon.srid)
            end


            def test_save_and_load_point_from_wkt
              klass_ = populate_ar_class(:latlon_point)
              obj_ = klass_.new
              obj_.latlon = 'POINT(1 2)'
              obj_.save!
              id_ = obj_.id
              obj2_ = klass_.find(id_)
              assert_equal(@factory.point(1, 2), obj2_.latlon)
              assert_equal(3785, obj2_.latlon.srid)
            end
end


            def test_add_column
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.column('latlon', :geometry)
              end
              klass_.connection.change_table(:spatial_test) do |t_|
                t_.column('geom2', :point, :srid => 4326)
                t_.column('name', :string)
              end
              assert_equal(2, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
              cols_ = klass_.columns
              assert_equal(::RGeo::Feature::Geometry, cols_[-3].geometric_type)
              assert_equal(-1, cols_[-3].srid)
              assert_equal(::RGeo::Feature::Point, cols_[-2].geometric_type)
              assert_equal(4326, cols_[-2].srid)
              assert_nil(cols_[-1].geometric_type)
            end


            def test_readme_example
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.column(:latlon, :point)
                t_.line_string(:path)
                t_.geometry(:shape)
              end
              klass_.connection.change_table(:spatial_test) do |t_|
                t_.index(:latlon, :spatial => true)
              end
              klass_.class_eval do
                self.rgeo_factory_generator = ::RGeo::Geos.method(:factory)
                set_rgeo_factory_for_column(:latlon, ::RGeo::Geographic.spherical_factory)
              end
              rec_ = klass_.new
              rec_.latlon = 'POINT(-122 47)'
              loc_ = rec_.latlon
              assert_equal(47, loc_.latitude)
              rec_.shape = loc_
              assert_equal(true, ::RGeo::Geos.is_geos?(rec_.shape))
            end


            def test_create_simple_geometry_using_shortcut
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.geometry 'latlon'
              end
              assert_equal(1, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
              assert_equal(::RGeo::Feature::Geometry, klass_.columns.last.geometric_type)
              assert(klass_.cached_attributes.include?('latlon'))
              klass_.connection.drop_table(:spatial_test)
              assert_equal(0, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
            end


            def test_create_point_geometry_using_shortcut
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.point 'latlon'
              end
              assert_equal(::RGeo::Feature::Point, klass_.columns.last.geometric_type)
              assert(klass_.cached_attributes.include?('latlon'))
            end


            def test_create_geometry_with_options
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.column 'region', :polygon, :srid => 3785
              end
              assert_equal(1, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
              col_ = klass_.columns.last
              assert_equal(::RGeo::Feature::Polygon, col_.geometric_type)
              assert_equal(3785, col_.srid)
              assert_equal({:srid => 3785, :type => 'polygon'}, col_.limit)
              assert(klass_.cached_attributes.include?('region'))
              klass_.connection.drop_table(:spatial_test)
              assert_equal(0, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
            end


            def test_create_geometry_using_limit
              klass_ = create_ar_class
              klass_.connection.create_table(:spatial_test) do |t_|
                t_.spatial 'region', :limit => {:srid => 3785, :type => :polygon}
              end
              assert_equal(1, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
              col_ = klass_.columns.last
              assert_equal(::RGeo::Feature::Polygon, col_.geometric_type)
              assert_equal(3785, col_.srid)
              assert_equal({:srid => 3785, :type => 'polygon'}, col_.limit)
              assert(klass_.cached_attributes.include?('region'))
              klass_.connection.drop_table(:spatial_test)
              assert_equal(0, klass_.connection.select_value("SELECT COUNT(*) FROM geometry_columns WHERE f_table_name='spatial_test'").to_i)
            end


          end

        end

      end
    end
  end
end
