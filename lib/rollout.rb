# frozen_string_literal: true

require 'rollout/version'
require 'zlib'
require 'set'
require 'json'

class Rollout
  RAND_BASE = (2**32 - 1) / 100.0

  class Feature
    attr_accessor :groups, :outlets, :percentage, :data
    attr_reader :name, :options

    def initialize(name, string = nil, opts = {})
      @options = opts
      @name    = name

      if string
        raw_percentage, raw_outlets, raw_groups, raw_data = string.split('|', 4)
        @percentage = raw_percentage.to_f
        @outlets = outlets_from_string(raw_outlets)
        @groups = groups_from_string(raw_groups)
        @data = raw_data.nil? || raw_data.strip.empty? ? {} : JSON.parse(raw_data)
      else
        clear
      end
    end

    def serialize
      "#{@percentage}|#{@outlets.to_a.join(',')}|#{@groups.to_a.join(',')}|#{serialize_data}"
    end

    def add_outlet(outlet)
      id = outlet_id(outlet)
      @outlets << id unless @outlets.include?(id)
    end

    def remove_outlet(outlet)
      @outlets.delete(outlet_id(outlet))
    end

    def add_group(group)
      @groups << group.to_sym unless @groups.include?(group.to_sym)
    end

    def remove_group(group)
      @groups.delete(group.to_sym)
    end

    def clear
      @groups = groups_from_string('')
      @outlets = outlets_from_string('')
      @percentage = 0
      @data = {}
    end

    def active?(rollout, outlet)
      if outlet
        id = outlet_id(outlet)
        outlet_in_percentage?(id) ||
          outlet_in_active_outlets?(id) ||
          outlet_in_active_group?(outlet, rollout)
      else
        @percentage == 100
      end
    end

    def outlet_in_active_outlets?(outlet)
      @outlets.include?(outlet_id(outlet))
    end

    def to_hash
      {
        percentage: @percentage,
        groups: @groups,
        outlets: @outlets
      }
    end

    private

    def outlet_id(outlet)
      if outlet.is_a?(Integer) || outlet.is_a?(String)
        outlet.to_s
      else
        outlet.send(id_outlet_by).to_s
      end
    end

    def id_outlet_by
      @options[:id_outlet_by] || :id
    end

    def outlet_in_percentage?(outlet)
      Zlib.crc32(outlet_id_for_percentage(outlet)) < RAND_BASE * @percentage
    end

    def outlet_id_for_percentage(outlet)
      if @options[:randomize_percentage]
        outlet_id(outlet).to_s + @name.to_s
      else
        outlet_id(outlet)
      end
    end

    def outlet_in_active_group?(outlet, rollout)
      @groups.any? do |g|
        rollout.active_in_group?(g, outlet)
      end
    end

    def serialize_data
      return '' unless @data.is_a? Hash

      @data.to_json
    end

    def outlets_from_string(raw_outlets)
      outlets = (raw_outlets || '').split(',').map(&:to_s)
      if @options[:use_sets]
        outlets.to_set
      else
        outlets
      end
    end

    def groups_from_string(raw_groups)
      groups = (raw_groups || '').split(',').map(&:to_sym)
      if @options[:use_sets]
        groups.to_set
      else
        groups
      end
    end
  end

  def initialize(storage, opts = {})
    @storage = storage
    @options = opts
    @groups  = { all: ->(_outlet) { true } }
  end

  def activate(feature)
    with_feature(feature) do |f|
      f.percentage = 100
    end
  end

  def deactivate(feature)
    with_feature(feature, &:clear)
  end

  def delete(feature)
    features = (@storage.get(features_key) || '').split(',')
    features.delete(feature.to_s)
    @storage.set(features_key, features.join(','))
    @storage.del(key(feature))
  end

  def set(feature, desired_state)
    with_feature(feature) do |f|
      if desired_state
        f.percentage = 100
      else
        f.clear
      end
    end
  end

  def activate_group(feature, group)
    with_feature(feature) do |f|
      f.add_group(group)
    end
  end

  def deactivate_group(feature, group)
    with_feature(feature) do |f|
      f.remove_group(group)
    end
  end

  def activate_outlet(feature, outlet)
    with_feature(feature) do |f|
      f.add_outlet(outlet)
    end
  end

  def deactivate_outlet(feature, outlet)
    with_feature(feature) do |f|
      f.remove_outlet(outlet)
    end
  end

  def activate_outlets(feature, outlets)
    with_feature(feature) do |f|
      outlets.each { |outlet| f.add_outlet(outlet) }
    end
  end

  def deactivate_outlets(feature, outlets)
    with_feature(feature) do |f|
      outlets.each { |outlet| f.remove_outlet(outlet) }
    end
  end

  def set_outlets(feature, outlets)
    with_feature(feature) do |f|
      f.outlets = []
      outlets.each { |outlet| f.add_outlet(outlet) }
    end
  end

  def define_group(group, &block)
    @groups[group.to_sym] = block
  end

  def active?(feature, outlet = nil)
    feature = get(feature)
    feature.active?(self, outlet)
  end

  def outlet_in_active_outlets?(feature, outlet = nil)
    feature = get(feature)
    feature.outlet_in_active_outlets?(outlet)
  end

  def inactive?(feature, outlet = nil)
    !active?(feature, outlet)
  end

  def activate_percentage(feature, percentage)
    with_feature(feature) do |f|
      f.percentage = percentage
    end
  end

  def deactivate_percentage(feature)
    with_feature(feature) do |f|
      f.percentage = 0
    end
  end

  def active_in_group?(group, outlet)
    f = @groups[group.to_sym]
    f&.call(outlet)
  end

  def get(feature)
    string = @storage.get(key(feature))
    Feature.new(feature, string, @options)
  end

  def set_feature_data(feature, data)
    with_feature(feature) do |f|
      f.data.merge!(data) if data.is_a? Hash
    end
  end

  def clear_feature_data(feature)
    with_feature(feature) do |f|
      f.data = {}
    end
  end

  def multi_get(*features)
    return [] if features.empty?

    feature_keys = features.map { |feature| key(feature) }
    @storage.mget(*feature_keys).map.with_index { |string, index| Feature.new(features[index], string, @options) }
  end

  def features
    (@storage.get(features_key) || '').split(',').map(&:to_sym)
  end

  def feature_states(outlet = nil)
    multi_get(*features).each_with_object({}) do |f, hash|
      hash[f.name] = f.active?(self, outlet)
    end
  end

  def active_features(outlet = nil)
    multi_get(*features).select do |f|
      f.active?(self, outlet)
    end.map(&:name)
  end

  def clear!
    features.each do |feature|
      with_feature(feature, &:clear)
      @storage.del(key(feature))
    end

    @storage.del(features_key)
  end

  def exists?(feature)
    @storage.exists(key(feature))
  end

  private

  def key(name)
    "feature:#{name}"
  end

  def features_key
    'feature:__features__'
  end

  def with_feature(feature)
    f = get(feature)
    yield(f)
    save(f)
  end

  def save(feature)
    @storage.set(key(feature.name), feature.serialize)
    @storage.set(features_key, (features | [feature.name.to_sym]).join(','))
  end
end
