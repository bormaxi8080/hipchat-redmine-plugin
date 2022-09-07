# encoding: utf-8

class NotificationHook < Redmine::Hook::Listener
  include IssuesHelper
  include CustomFieldsHelper

  @@to_user_key

  def text_formatting(url, issue, tracker, info, comment, action)
    text = "<p>"
    text += "Задача <a href=\"#{url}\">##{issue.id} - #{tracker}</a> была #{action}<br>"
    text += "#{issue.subject}<br>"

    if info.count > 0
      text += "<ul>"
      for j in info;
        text += "<li>#{j}</li>"
      end
      text += "</ul>"
    end

    text += "<p><i>#{truncate(comment)}</i></p>"
    text += "</p>"

    return text
  end


  # New task
  def controller_issues_new_after_save(context = {})
    data = {}
    issue = context[:issue]
    to_user_id = User.current.id
    from_user_id = issue.assigned_to_id

    return true if !configured?(to_user_id, from_user_id)

    data[:to_user_key] = @@to_user_key
    data[:from_user_email] = User.find(from_user_id).mail


    tracker = CGI::escapeHTML(issue.tracker.name.downcase)
    url = get_url(issue)

    data[:text] = text_formatting(url, issue, tracker, [], '', 'создана')

    # Отправка
    send_message(data)

  end

  # Save task
  def controller_issues_edit_after_save(context = {})

    data = {}

    issue = context[:issue]
    journal = context[:journal]
    tracker = CGI::escapeHTML(issue.tracker.name.downcase)
    comment = CGI::escapeHTML(journal.notes)
    url = get_url(issue)
    info = details_to_strings(journal.details, true)
    to_user_id = User.current.id
    from_user_id = issue.assigned_to_id

    return true if !configured?(to_user_id, from_user_id)

    data[:to_user_key] = @@to_user_key
    data[:from_user_email] = User.find(from_user_id).mail

    data[:text] = text_formatting(url, issue, tracker, info, comment, 'обновлена')

    # Отправка
    send_message(data)
  end

  private
  # Check user settings and key checkboxes
  def configured?(to_user_id, from_user_id)
    id_key = Setting.plugin_redmine_hipchat_notification[:id_key]
    id_notification = Setting.plugin_redmine_hipchat_notification[:id_notification]

    if to_user_id && from_user_id
      from_user_notification = User.find(from_user_id).custom_value_for(id_notification)
      @@to_user_key = User.find(to_user_id).custom_value_for(id_key)

      if id_key && id_notification && @@to_user_key && from_user_notification.to_s == '1'
        return true
      end
    end

    return false
  end

  def get_url(object)
    case object
      when Issue then
        "#{Setting[:protocol]}://#{Setting[:host_name]}/issues/#{object.id}"
      else
        Rails.logger.info "Asked redmine_hipchat for the url of an unsupported object #{object.inspect}"
    end
  end

  def send_message(data)

    Rails.logger.info "Sending message to HipChat: #{data[:text]}"
    req = Net::HTTP::Post.new("/v2/user/#{data[:from_user_email]}/message")
    req.body ={
        :message => data[:text],
        :message_format => 'html',
        :notify => true
    }.to_json

    req["Content-Type"] = 'application/json'
    req["Authorization"] = "Bearer #{data[:to_user_key]}"

    http = Net::HTTP.new("api.hipchat.com", 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    begin
      http.start do |connection|
        connection.request(req)
      end
    rescue Net::HTTPBadResponse => e
      Rails.logger.error "Error hitting HipChat API: #{e}"
    end
  end

  def truncate(text, length = 20, end_string = '…')
    return unless text
    words = text.split()
    words[0..(length-1)].join(' ') + (words.length > length ? end_string : '')
  end
end
