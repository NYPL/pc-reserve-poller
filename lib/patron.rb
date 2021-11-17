require_relative './patron_service'

class Patron
  attr_accessor :event, :data, :patron_service_response

  def initialize (data)
    @data = data
    @patron_service_response = PatronService.new @data["pcrUserID"]
  end

  #  patron_id: Interpret pcrUserID as a patron barcode.
  # Use the PatronService to convert it to a patronId.
  # Apply bcrypt obfuscation documented with samples here and implemented in Java here.
  def patron_id
    obfuscate patron_service_response.patron_id
  end

  #  ptype_code: Using patron record already fetched, evaluate fixedFields[“47”][“value”]
  def ptype_code
  end

  #  patron_home_library_code: Using patron record already fetched, evaluate fixedFields[“53”][“value”]. Trim whitespace.
  def patron_home_library_code
  end

  #  pcode3: Using patron record already fetched, evaluate patronCodes[“pcode3”].
  def pcode3
  end

  #  postal_code: Query from Sierra directly (see “Patron Postal Code Concerns”)
  def postal_code
  end

  #  geoid: Placeholder for future census tract work. Set to null. (We’re only adding it now because it’s challenging to modify Avro schemas later once the pipeline is active.)
  def geoid
    nil
  end

  # key: Obfuscated crKey (see documentation on obfuscation techniques)
  def key
    obfuscate data["pcrKey"]
  end

  # minutes_used
  def minutes_used
    data["pcrMinutesUsed"]
  end

  # transaction_et: pcrDateTime converted to ET, cast to DATE
  def transaction_et
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
