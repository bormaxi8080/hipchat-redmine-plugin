Redmine::Plugin.register :redmine_hipchat_notification do
  name 'HipChat Notifications'
  author 'imaxi'
  description 'Notifications in private messages of HipChat users'
  version '1.0.0'
  url 'https://github.com/bormaxi8080/hipchat-redmine-plugin.git'

  Rails.configuration.to_prepare do
    require_dependency 'hipchat_notification_hooks'
  end

  settings :partial => 'settings/redmine_hipchat_notification',
           :default => {
               :id_key => "",
               :id_notification => "",
           }
end
