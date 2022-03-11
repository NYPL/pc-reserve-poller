require_relative './obfuscation_helper'
require_relative './sierra_db_client'
require_relative './safe_navigation_wrapper'

class PcReserve
  attr_accessor :event, :data, :patron

  def initialize (data, sierra_batch, patron_batch)
    @data = data
    @barcode = @data["pcrUserID"]
    @patron = patron_batch[@barcode] || SafeNavigationWrapper.new(nil)
    @id = @patron["id"].value ? @patron["id"].value.to_s : nil
    @sierra_batch = sierra_batch
    @patron_batch = patron_batch
  end

  #  patron_id: Interpret pcrUserID as a patron barcode.
  # Use the PatronService to convert it to a patronId.
  # Apply bcrypt obfuscation documented with samples here and implemented in Java here.
  def patron_id
    ObfuscationHelper.obfuscate(@id || "barcode #{@barcode}")
  end

  #  ptype_code: Using patron record already fetched, evaluate fixedFields[“47”][“value”]
  def ptype_code
    code = patron["fixedFields"]["47"]["value"].value
    code ? code.to_i : nil
  end

  #  patron_home_library_code: Using patron record already fetched, evaluate fixedFields[“53”][“value”]. Trim whitespace.
  def patron_home_library_code
    code = patron["fixedFields"]["53"]["value"].value
    code ? code.strip : nil
  end

  #  pcode3: Using patron record already fetched, evaluate patronCodes[“pcode3”].
  def pcode3
    patron["patronCodes"]["pcode3"].value
  end

  #  postal_code: Query from Sierra directly (see “Patron Postal Code Concerns”)
  def postal_code
    $logger.debug("Sierra batch : #{@sierra_batch}")
    sierra_resp = @sierra_batch[@id]

    if !sierra_resp
      $logger.warn("#{$batch_id} Received no matching postal code #{data["pcrKey"]}")
      nil
    else
      sierra_resp
    end

  end

  #  geoid: Placeholder for future census tract work. Set to null. (We’re only adding it now because it’s challenging to modify Avro schemas later once the pipeline is active.)
  def geoid
    nil
  end

  # key: Obfuscated crKey (see documentation on obfuscation techniques)
  def key
    ObfuscationHelper.obfuscate data["pcrKey"]
  end

  # minutes_used
  def minutes_used
    data["pcrMinutesUsed"]
  end

  # transaction_et: pcrDateTime
  def transaction_et
    data["pcrDateTime"].to_s
  end

  # branch: pcrBranch
  def branch
    data["pcrBranch"]
  end

  # area: pcrArea
  def area
    data["pcrArea"]
  end

  # staff_override: Value of pcrUserData1?
  def staff_override
    data["pcrUserData1"]
  end

  def patron_retrieval_status
    @patron["status"].value
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
    $logger.debug("Pushing event: ", { event: event, patron: patron.value, data: data, sierra_batch: @sierra_batch })
    $kinesis_client << event
  end

  def process
    build_event_from_data
    push_event
  end
end
