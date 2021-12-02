require_relative './patron'
require_relative './obfuscation_helper'
require_relative './pg_manager'

class PcReserve
  attr_accessor :event, :data, :patron

  def initialize (data, sierra_batch, patron_batch)
    @data = data
    @barcode = @data["pcrUserID"]
    @patron = Patron.from patron_batch[@id]
    @id = @patron["id"]
    @sierra_batch = sierra_batch
  end

  #  patron_id: Interpret pcrUserID as a patron barcode.
  # Use the PatronService to convert it to a patronId.
  # Apply bcrypt obfuscation documented with samples here and implemented in Java here.
  def patron_id
    ObfuscationHelper.obfuscate patron["id"].value
  end

  #  ptype_code: Using patron record already fetched, evaluate fixedFields[“47”][“value”]
  def ptype_code
    patron["fixedFields"]["47"]["value"].value
  end

  #  patron_home_library_code: Using patron record already fetched, evaluate fixedFields[“53”][“value”]. Trim whitespace.
  def patron_home_library_code
    patron["fixedFields"]["53"]["value"].value.strip
  end

  #  pcode3: Using patron record already fetched, evaluate patronCodes[“pcode3”].
  def pcode3
    patron["patronCodes"]["pcode3"].value
  end

  #  postal_code: Query from Sierra directly (see “Patron Postal Code Concerns”)
  def postal_code
    sierra_resp = sierra_batch[@id]

    if !sierra_resp
      $logger.warn('Received no matching postal code')
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
    data["pcrDateTime"]
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
      ]
      self.event = fields.map {|field| [ field, self.send(field) ]}.to_h
  end

  def push_event
    $kinesis_client << event
  end

  def process
    build_event_from_data
    push_event
  end
end
