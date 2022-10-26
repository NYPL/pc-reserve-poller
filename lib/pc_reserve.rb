require_relative './obfuscation_helper'
require_relative './safe_navigation_wrapper'
require_relative './sierra_db_client'

# A class representing a single PcReserve record with helper methods to combine data
# from Envisionware, Platform, and Sierra and to push an event to the Kinesis client.
class PcReserve

  attr_accessor :event, :data, :patron, :sierra_resp

  def initialize (data, sierra_map, patron_map)
    @data = data
    @barcode = @data["pcrUserID"]
    @patron = patron_map[@barcode] || SafeNavigationWrapper.new(nil)
    @id = @patron["id"].value ? @patron["id"].value.to_s : nil
    @sierra_resp = sierra_map[@id]
    $logger.debug("Patron: #{@patron.value}")
    $logger.debug("Sierra response : #{@sierra_resp}")
  end

  # patron_id: Obfuscated patron record ID from Sierra.
  def patron_id
    if (!sierra_resp || !sierra_resp[:patron_record_id] || !(sierra_resp[:patron_record_id].is_a? String))
      $logger.debug("#{$batch_id} Received no matching patron id for barcode #{@barcode}")
      ObfuscationHelper.obfuscate("barcode #{@barcode}")
    else
      ObfuscationHelper.obfuscate(sierra_resp[:patron_record_id])
    end
  end

  # ptype_code: fixedFields[“47”][“value”] of patron record trimmed of whitespace.
  def ptype_code
    code = patron["fixedFields"]["47"]["value"].value
    code ? code.to_i : nil
  end

  # patron_home_library_code: fixedFields[“53”][“value”] of patron record trimmed of whitespace.
  def patron_home_library_code
    code = patron["fixedFields"]["53"]["value"].value
    code ? code.strip : nil
  end

  # pcode3: patronCodes[“pcode3”] of patron record.
  def pcode3
    patron["patronCodes"]["pcode3"].value
  end

  # postal_code: Five-digit postal code from Sierra.
  def postal_code    
    if !sierra_resp || !sierra_resp[:postal_code] || !(sierra_resp[:postal_code].is_a? String)
      $logger.debug("#{$batch_id} Received no matching postal code for barcode #{@barcode}")
      nil
    else
      postal_regex = /^(\d{5})(-\d{4})?$/ # original postal code should be formatted as: 12345-6789
      match_data = postal_regex.match(sierra_resp[:postal_code])
      if !match_data || !match_data[1]
        $logger.warn("#{$batch_id} Received ill-formatted postal code type for barcode #{@barcode}: #{sierra_resp[:postal_code]}")
        return nil
      else
        return match_data[1]
      end
    end
  end

  # geoid: Placeholder for future census tract work. Set to null.
  # (We’re only adding it now because it’s challenging to modify Avro schemas later once the pipeline is active.)
  def geoid
    nil
  end

  # key: Obfuscated pcrKey
  def key
    ObfuscationHelper.obfuscate data["pcrKey"]
  end

  # minutes_used: pcrMinutesUsed from Envisionware db.
  def minutes_used
    data["pcrMinutesUsed"]
  end

  # transaction_et: pcrDateTime from Envisionware db.
  def transaction_et
    data["pcrDateTime"].to_date.to_s
  end

  # branch: pcrBranch from Envisionware db.
  def branch
    data["pcrBranch"]
  end

  # area: pcrArea from Envisionware db.
  def area
    data["pcrArea"]
  end

  # staff_override: pcrUserData1 from Envisionware db.
  def staff_override
    data["pcrUserData1"]
  end

  # patron_retrieval_status: Whether the patron could be retrieved from Platform using the pcrUserID as a barcode.
  def patron_retrieval_status
    patron["status"].value
  end

  def build_event_from_data
      fields = [
        :patron_id,
        :ptype_code,
        :patron_home_library_code,
        :pcode3,
        :postal_code,
        :geoid,
        :key,
        :minutes_used,
        :transaction_et,
        :branch,
        :area,
        :staff_override,
        :patron_retrieval_status
      ]
      self.event = fields.map do |field|
        begin
          [ field, self.send(field) ]
        rescue StandardError => e
          $logger.error("Problem with field #{field} in data #{@data}")
        end
      end.to_h
  end

  def push_event
    $logger.debug("Pushing event: ", { event: event, patron: patron.value, data: data, sierra_resp: @sierra_resp })
    $kinesis_client << event
  end

  def process
    build_event_from_data
    push_event
  end

end
