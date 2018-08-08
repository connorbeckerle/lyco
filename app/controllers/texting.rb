get "/" do
  erb :index
end

post "/" do
  numbers = params[:numbers].to_s
  message = [*params[:message]]

  Thread.new do
    process_texts(numbers: numbers, message: message) do |chunk|
      send_ws(chunk)
    end
  end

  204
end

def process_texts(numbers:, message:)
  contacts = parse_contacts(numbers)
  message_parts = message.map(&:strip).reject(&:empty?).map(&:normalize_newlines)

  begin_msg = "Sending a #{message_parts.length}-part " +
    "message to #{contacts.length} contacts"

  settings.log.info(begin_msg)
  yield begin_msg + "\n"

  num_contacted = 0
  num_errors = 0

  contacts.each do |contact|
    begin
      yield "Sending message to #{contact}"

      message_parts.each_with_index do |part, i|
        send_sms!(to: contact, body: part)
        yield " (part #{i + 1})"
      end

      yield " [OK]\n"

      num_contacted += 1
    rescue => e
      num_errors += 1

      yield " [Error] #{e.message}\n"
    end
  end

  yield "Done. Sent #{num_contacted} messages, #{num_errors} errors.\n"
end
