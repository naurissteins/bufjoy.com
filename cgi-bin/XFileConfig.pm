package XFileConfig;
use strict;
use utf8;
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;
#use Net::SSL;
use lib 'Modules';
use Exporter;
@XFileConfig::ISA    = qw(Exporter);
@XFileConfig::EXPORT = qw($c);
use vars qw( $c );

$c=
{
 license_key => 'yztnf2p4uk2izujuaq3bguwg2kkmw4dmcvimoaeoznwefmuyck5dszpeynd6ezius5ktaxbu7nxh5jqwojkxwpstqkhlifppnmxo6sehepjblwq',

 # MySQL settings
 db_host => 'localhost',
 db_login => 'xvs',
 db_passwd => 'lolix1161',
 db_name => 'xvs',

 #db_slaves => ['localhost'],

 default_language => '1',

 # Passwords crypting random salt. Set it up once when creating system
 pasword_salt => 'b6f15najvk10',

 # Secret key to crypt Download requests
 dl_key => '90t3e1p3w5abr9nt',

 user_agent => 'XVSntee8yab1powxo9',

 main_server_ip => '95.217.8.204',

 # Your site name that will appear in all templates
 site_name => 'XVideoSharing',

 # Your site URL, witout trailing /
 site_url => 'https://bufjoy.com',

 # Your site cgi-bin URL, witout trailing /
 site_cgi => 'https://bufjoy.com/cgi-bin',

 cdn_url => 'https://bufjoy.com',

 # Path to your site htdocs folder
 site_path => '/var/www/htdocs',

 cgi_path => '/var/www/cgi-bin',

 # FastCGI mode
 fast_cgi => '',

 # UTF8 sql fix
 sql_utf8_fix => '1',

 # Delete Direct Download Links after X hours
 symlink_expire => '12', # hours

 # Do not expire premium user's files
 dont_expire_premium => '1',

 # Generated links format, 0-5
 link_format => '5',

 enable_search => '1',

 # Banned IPs
 # Examples: '^(10.0.0.182)$' - ban 10.0.0.182, '^(10.0.1.125|10.0.0.\d+)$' - ban 10.0.1.125 & 10.0.0.*
 # Use \d+ for wildcard *
 ip_not_allowed => '^(10.0.0.182)$',

 # Banned filename parts
 fnames_not_allowed => '(warez|xvideo)',

 # Use captcha verification to avoid robots
 # 0 - disable captcha, 1 - image captcha (requires GD perl module installed), 2 - text captha, 3 - reCaptcha
 captcha_mode => '3',

 # Enable users to add descriptions to files
 enable_file_descr => '1',

 category_required => '',

 # Allow users to add comments to files
 enable_file_comments => '1',

 # Replace all chars except "a-zA-Z0-9.-" with underline
 sanitize_filename => '',

 # Used for BW limit
 bw_limit_days => '3',

 charset => 'UTF-8',

 # Require e-mail registration
 registration_confirm_email => '1',

 # Mail servers not allowed for registration
 # Sample: 'mailinator.com|gmail.com'
 mailhosts_not_allowed => '(mailinator.com|yopmail.com|temp-mail.org|minuteinbox.com|10minutemail.com|tempmailaddress.com|emailondeck.com)',

 # Reject comments with banned words
 bad_comment_words => '(fuck|shit)',

 # Add postfix to filename
 add_filename_postfix => '',

 # Keys used for reCaptcha
 recaptcha_pub_key => '',
 recaptcha_pri_key => '',

 ping_google_sitemaps => '1',

#--- Anonymous users limits ---#

 # Enable anonymous upload
 enabled_anon => '',

 upload_enabled_anon => '',

 # Maximum upload Filesize in Mbytes (0 to disable)
 max_upload_filesize_anon => '',

 # Specify number of seconds users have to wait before download, 0 to disable
 download_countdown_anon => '2',

 # Captcha for downloads
 captcha_anon => '',

 # Show advertisement
 ads_anon => '1',

 # Limit Max bandwidth for IP per 'bw_limit_days' days
 bw_limit_anon => '3',

 # Add download delay per 100 Mb file, seconds
 add_download_delay_anon => '',

 # Download speed limit, Kbytes/s
 down_speed_anon => '100',
 watch_speed_anon => '220',

 # Maximum download size in Mbytes (0 to disable) 
 max_download_filesize_anon => '500',

 pre_download_anon => '',

 time_slider_anon => '1',

 video_player_anon => '1',

 download_anon => '1',

 video_time_limit_anon => '',

#------#

#--- Registered users limits ---#

 # Enable user registration
 enabled_reg => '1',

 upload_enabled_reg => '1',

 # Allow remote URL uploads
 remote_url_reg => '1',

 # Maximum disk space in Mbytes (0 to disable)
 disk_space_reg => '7',

 # Maximum upload Filesize in Mbytes (0 to disable)
 max_upload_filesize_reg => '2500',

 max_upload_files_reg => '30',

 # Specify number of seconds users have to wait before download, 0 to disable
 download_countdown_reg => '1',

 # Captcha for downloads
 captcha_reg => '',

 # Show advertisement
 ads_reg => '1',

 # Limit Max bandwidth for IP per 'bw_limit_days' days
 bw_limit_reg => '3',

 # Add download delay per 100 Mb file, seconds
 add_download_delay_reg => '',

 # Download speed limit, Kbytes/s
 down_speed_reg => '100',
 watch_speed_reg => '250',

 # Maximum download size in Mbytes (0 to disable) 
 max_download_filesize_reg => '1000',

 torrent_dl_slots_reg => '1',

 pre_download_reg => '',

 queue_url_max_reg => '3',

 queue_url_working_max_reg => '1',

 time_slider_reg => '1',

 video_player_reg => '1',

 download_reg => '1',

 video_time_limit_reg => '',

#------#

#--- Premium users limits ---#

 # Enable premium accounts
 enabled_prem => '1',

 upload_enabled_prem => '1',

 # Maximum disk space in Mbytes (0 to disable)
 disk_space_prem => '10',

 # Maximum upload Filesize in Mbytes (0 to disable)
 max_upload_filesize_prem => '3000',

 max_upload_files_prem => '0',

 # Specify number of seconds users have to wait before download, 0 to disable
 download_countdown_prem => '',

 # Captcha for downloads
 captcha_prem => '',

 # Show advertisement
 ads_prem => '1',

 # Limit Max bandwidth for IP per 'bw_limit_days' days
 bw_limit_prem => '2000',

 # Add download delay per 100 Mb file, seconds
 add_download_delay_prem => '',

 # Allow remote URL uploads
 remote_url_prem => '1',

 # Download speed limit, Kbytes/s
 down_speed_prem => '1000',
 watch_speed_prem => '220',

 # Maximum download size in Mbytes (0 to disable) 
 max_download_filesize_prem => '0',

 torrent_dl_slots_prem => '1',

 pre_download_prem => '',

 queue_url_max_prem => '5',

 queue_url_working_max_prem => '1',

 time_slider_prem => '1',

 video_player_prem => '1',

 download_prem => '1',

 video_time_limit_prem => '',

#------#

 # Logfile name
 admin_log => 'main_log.txt',

 items_per_page => '20',

 # Files per dir, do not touch since server start
 files_per_folder => 5000,

 # Do not use, for demo site only
 demo_mode => 0,

##### Email settings #####

 # SMTP settings (optional)
 smtp_server => '', #smtp.gmail.com for gmail, install Net::SMTP::TLS
 smtp_user => '',
 smtp_pass => '',
 smtp_auth => '', #tls for gmail, try tls2 also

 # This email will be in "From:" field in confirmation & contact emails
 email_from => '',

 # Email that Contact messages will be sent to
 contact_email => '',

 # Premium users payment plans
 # Example: 5.00=7,9.00=14,15.00=30 ($5.00 adds 7 premium days)
 payment_plans => '5.00=7',

 views_profit_on => '1',

 tier_sizes => '0|1|3|10',

 tier1_countries => 'US|UK|CA|GB',
 tier2_countries => 'DE|FR|ES',
 tier3_countries => 'PT|RU',
 tier4_countries => 'KZ|UA',

 tier1_money => '3|2|1|1',
 tier2_money => '2|1|1|1',
 tier3_money => '1|1|1|1',
 tier4_money => '1|1|1|0',
 tier5_money => '0.5|0.5|0.5|0',

 track_views_percent => '40',

 ### Payment settings ###

 item_name => 'Premium',
 currency_code => 'USD',

 # User registration coupons
 coupons => '',

 #external_links => 'http://sibsoft.net|SibSoft labs~https://upload-pro.com|XFilesharing demo',

 # Language list to show on site
 #languages_list => ['english','russian','german','french','arabic','turkish','polish','thai','spanish','japan','hungary','indonesia'],

 # Match list between browser language code and language file
 # Full list could be found here: http://www.livio.net/main/charset.asp#language
 language_codes => {'en.*'             => 'english',
                    #'cs'               => 'czech',
                    #'da'               => 'danish',
                    #'fr.*'             => 'french',
                    #'de.*'             => 'german',
                    #'p'                => 'polish',
                    'ru'               => 'russian',
                    #'es.*'             => 'spanish',
                   },

 # Cut long filenames in MyFiles,AdminFiles
 display_max_filename => '64',
 display_max_filename_admin => '52',

 # Delete records from IP2Files older than X days
 clean_ip2files_days => '7',

 anti_dupe_system => '1',

 m_d => '1',
 m_d_f => '1',
 m_d_a => '1',
 m_d_c => '1',
 m_d_featured => '1',
 m_d_file_approve => '',
 m_d_legal => '1',
 m_d_f_limit => '3',

 deurl_site => '',
 deurl_api_key => '',

 m_ads => '',

 m_v_width => '940',
 m_v_height => '',

 video_embed_anon => '',
 video_embed_reg => '1',
 video_embed_prem => '1',

 files_expire_access_anon => '',
 files_expire_access_reg => '180',
 files_expire_access_prem => '365',

 # Add download delay after each file download, seconds
 file_dl_delay_anon => '120',
 file_dl_delay_reg => '120',
 file_dl_delay_prem => '60',

 max_money_last24 => '10',

 sale_aff_percent => '50',

 referral_aff_percent => '5',

 min_payout => '50',

 del_money_file_del => '1',

 convert_money => '5',
 convert_days => '15',

 m_t => '',
 m_t_users => 'registered',

 m_x => '1',
 m_x_width => '1280',
 m_x_cols => '3',
 m_x_rows => '3',
 m_x_logo => 'bufjoy',
 m_x_prem_only => '',
 m_x_th_width => '600',
 m_x_th_height => '600',

 vid_keep_orig => '',

 m_h => '1',

 # Normal quality
 vid_encode_n => '',
 vid_resize_n => 'x480',
 vid_quality_mode_n => 'crf',
 vid_quality_n => '25',
 vid_bitrate_n => '500',
 vid_audio_bitrate_n => '96',
 vid_audio_rate_n => '44100',
 vid_audio_channels_n => '2',
 vid_preset_n => 'faster',
 vid_preset_alt_n => 'veryfast',
 vid_enc_anon_n => '1',
 vid_enc_reg_n => '1',
 vid_enc_prem_n => '1',
 vid_play_anon_n => '1',
 vid_play_reg_n => '1',
 vid_play_prem_n => '1',
 vid_crf_bitrate_max_n => '',
 watch_speed_n => '300',
 watch_speed_auto_n => '',
 vid_transcode_max_bitrate_n => '0',
 vid_transcode_max_abitrate_n => '0',


 # Low mobile quality
 vid_encode_l => '',
 vid_resize_l => 'x360',
 vid_quality_mode_l => 'crf',
 vid_quality_l => '26',
 vid_bitrate_l => '400',
 vid_audio_bitrate_l => '64',
 vid_audio_rate_l => '44100',
 vid_audio_channels_l => '1',
 vid_preset_l => 'faster',
 vid_preset_alt_l => 'veryfast',
 vid_enc_anon_l => '1',
 vid_enc_reg_l => '1',
 vid_enc_prem_l => '1',
 vid_play_anon_l => '1',
 vid_play_reg_l => '1',
 vid_play_prem_l => '1',
 vid_fps_l => '',
 vid_crf_bitrate_max_l => '',
 watch_speed_l => '100',
 watch_speed_auto_l => '',
 vid_transcode_max_bitrate_l => '0',
 vid_transcode_max_abitrate_l => '0',


 # High quality
 vid_encode_h => '',
 vid_resize_h => 'x720',
 vid_quality_mode_h => 'crf',
 vid_quality_h => '24',
 vid_bitrate_h => '1200',
 vid_audio_bitrate_h => '128',
 vid_audio_rate_h => '44100',
 vid_audio_channels_h => '2',
 vid_preset_h => 'faster',
 vid_preset_alt_h => 'veryfast',
 vid_enc_anon_h => '',
 vid_enc_reg_h => '1',
 vid_enc_prem_h => '1',
 vid_play_anon_h => '1',
 vid_play_reg_h => '1',
 vid_play_prem_h => '1',
 vid_crf_bitrate_max_h => '3500',
 watch_speed_h => '600',
 watch_speed_auto_h => '',
 vid_transcode_max_bitrate_h => '0',
 vid_transcode_max_abitrate_h => '0',


 # High2 quality
 vid_encode_x => '1',
 vid_resize_x => 'x1080',
 vid_quality_mode_x => 'crf',
 vid_quality_x => '23',
 vid_bitrate_x => '1200',
 vid_audio_bitrate_x => '192',
 vid_audio_rate_x => '48000',
 vid_audio_channels_x => '2',
 vid_preset_x => 'faster',
 vid_preset_alt_x => 'veryfast',
 vid_enc_anon_x => '',
 vid_enc_reg_x => '1',
 vid_enc_prem_x => '1',
 vid_play_anon_x => '1',
 vid_play_reg_x => '1',
 vid_play_prem_x => '1',
 vid_crf_bitrate_max_x => '',
 watch_speed_x => '1000',
 watch_speed_auto_x => '',
 vid_transcode_max_bitrate_x => '3000',
 vid_transcode_max_abitrate_x => '300',


 m_y => '',
 ssd_hours => '00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23',

 payout_systems => 'PayPal, Webmoney, BitCoin',

 twit_consumer1 => '',
 twit_consumer2 => '',


 show_more_files => '',

 more_files_number => '3',

 bad_ads_words => '(zoo|rape|child)',

 cron_test_servers => '',

 # Resellers mod
 m_k => '1',
 m_k_plans => '11.99=30d,19.99=90d',
 m_k_manual => '1',
 m_k_add_money => '1',
 m_k_add_money_list => '10.00,50.00,100.00',

 deleted_files_reports => '',

 
 facebook_app_id_like => '',
 facebook_like_on => '',
 facebook_comments => '',

 # Index page settings
 index_featured_on => '1',
 index_featured_num => '6',
 index_featured_min_length => '',
 index_featured_max_length => '',

 index_most_viewed_on => '1',
 index_most_viewed_num => '6',
 index_most_viewed_hours => '999',
 index_most_viewed_min_length => '',
 index_most_viewed_max_length => '',

 index_most_rated_on => '1',
 index_most_rated_num => '6',
 index_most_rated_hours => '999',
 index_most_rated_min_length => '',
 index_most_rated_max_length => '',

 index_just_added_on => '1',
 index_just_added_num => '6',
 index_just_added_min_length => '',
 index_just_added_max_length => '',

 # Video extensions
 video_extensions => 'avi|mkv|mpg|mpeg|vob|wmv|flv|mp4|mov|m4v|m2v|3gp|webm|ogv|ogg',

# Image extensions
image_extensions => 'jpg|jpeg|png|gif|tiff|bmp|webp|raw|svg|heif|heic', 

# Archive extensions
archive_extensions => 'zip|rar|7z|tar|gz|bz2|xz|gzip',

 enc_queue_premium_priority => '5',

 # TimeSlider mod
 m_z => '1',
 m_z_cols => '5',
 m_z_rows => '5',

 server_transfer_speed => '2000',
 optimize_hdd_perfomance => '1',

 # Video Preview mod
 m_p => '',
 m_p_parts => '3',
 m_p_length => '3',
 m_p_show_anon => '1',
 m_p_show_reg => '1',
 m_p_show_prem => '',
 m_p_source => 'n',
 m_p_custom_upload => '',

 thumb_width => '200',
 thumb_height => '112',

 m_v => '',
 m_v_users => 'special',
 #m_v_fonts => '',
 m_v_image_logo => '1',
 m_v_image_max_size => '300',

 m_s => '1',
 m_s_users => 'registered',
 m_s_samples => '6',
 m_s_upload => '1',

 m_g => '1',
 m_g_users => '',
 m_g_frames_max => '',

 files_expire_limit => '500',

 news_enabled => '1',

 thumb_position => '30%',

 approve_required => '',
 approve_required_first => '',

 uploads_selected_only => '',

 m_l => '',
 
 twitter_api_key => '',
 twitter_api_secret => '',

 facebook_app_id => '',
 facebook_app_secret => '',

 vk_app_id => '',
 vk_app_secret => '',

 google_app_id => '',
 google_app_secret => '',

 google_plus_client_id => '',

 file_data_fields => '',

 m_f => '1',
 m_f_users => 'registered',
 m_f_subdomain => 'ftp.site.com',

 file_cloning => '',

 resolve_ip_country => '',

 m_b => '1',
 m_b_users => 'special',
 m_b_rate => '5',

 m_c => '',
 m_c_views_rate1 => '10',
 m_c_views_num1 => '5',
 m_c_views_rate2 => '30',
 m_c_views_num2 => '20',
 m_c_views_user => '2',
 m_c_views_skip => '1',
 m_c_sale_init_rate => '10',
 m_c_sale_renew_rate => '20',
 m_c_sale_user => '1',

 srt_on => '1',
 srt_langs => '',
 srt_max_size_kb => '300',
 srt_color => '#FFFFFF',
 srt_shadow_color => 'transparent',
 srt_back_color => '#303030',
 srt_font => 'Arial',
 srt_size => '100',
 srt_size_px => '25',
 srt_edge_style => '',
 srt_opacity => '30',
 srt_opacity_text => '100',

 extra_user_fields => 'Country',

 maintenance_upload => '',
 maintenance_upload_msg => '',
 maintenance_download => '',
 maintenance_download_msg => '',
 maintenance_full => '',
 maintenance_full_msg => '',

 m_o => '1',

 login_limit1_ips => '',
 login_limit1_hours => '',
 login_limit1_subnets => '',
 login_limit2_max => '',
 login_limit2_hours => '',

 m_e => '1',
 m_e_users => '',

 vid_resize_method => '0',

 fs_logs_on => '',

 player_js_encode => '1',

 max_url_uploads_user => '',

 m_j => '',
 m_j_domain => '',
 m_j_instant => '',
 m_j_hide => '',

 sales_profit_on => '1',

 tier_factor => '',

 no_reencoding_mp4 => '',
 no_reencoding_flv => '',

 vid_container_n => 'mp4',
 vid_container_h => 'mp4',
 vid_container_l => 'mp4',

 xframe_allow_frames => '',

 ssd_max_filesize => '',
 player_sharing => '1',

 tos_accept_checkbox => '',

 srt_auto => '1',
 srt_auto_langs => 'eng=English, rus=Russian, fre=French, fra=French, tur=Turkish, ger=German, deu=German, spa=Spanish, esp=Spanish, gre=Greek, ita=Italian, ara=Arabic, bul=Bulgarian, cat=Catalan, chi=Chinese, zho=Chinese, heb=Hebrew, jpn=Japanese, may=Malay, ind=Indonesian, tha=Thai, ukr=Ukrainian',

 m_u => '',
 memcached_address => '127.0.0.1:11211',
 memcached_expire => '60',

 custom_snapshot_upload => '300',

 m_f_update_on_cron => '1',
 m_f_update_on_reg => '1',
 m_f_update_on_buy => '1',
 m_f_sync_files_after => '3',

 ### Payment systems configs ###
 paypal_email => '',
 paypal_url    => 'https://www.paypal.com/cgi-bin/webscr',
 #paypal_url	=> 'https://www.sandbox.paypal.com/cgi-bin/webscr',
 paypal_subscription => '',

 firstdatapay_gateway_id => '',
 firstdatapay_password => '',
 firstdatapay_hmac_key => '',
 firstdatapay_key_id => '',

 downloadnolimit_site_id => '',
 downloadnolimit_secret => '',

 paysafecard_username => '',
 paysafecard_password => '',

 ikoruna_czk_rate => '',
 ikoruna_p_id => '',
 ikoruna_secret => '',
 pcash_site_id => '',
 sprypay_shop_id => '',
 perfectmoney_account => '',
 perfectmoney_secret => '',
 junglepay_campaign_id => '',
 click2sell_products => '',
 matomy_placement_id => '',
 matomy_secret => '',
 paylink_url => 'https://paylink.cc/process.htm',
 paylink_products => '',
 paylink_member => '',
 paylink_subscription => '',
 paylink_trial_days => '',
 authorize_login_id => '',
 authorize_secret => '',

 okpay_receiver => '',
 okpay_url    => 'https://www.okpay.com/ipn-verify.html',

 hipay_url => '',
 #hipay_url => 'https://test-payment.hipay.com/order/',
 hipay_merchant_id => '',
 hipay_merchant_password => '',
 hipay_website_id => '',
 pwall_app_id => '',
 pwall_secret_key => '',
 posonline_operator_id => '',
 posonline_secret => '',

 two_checkout_sid => '',
 daopay_app_id => '',

 cashu_merchant_id => '',
 plimus_contract_id => '',

 moneybookers_email => '',
 webmoney_merchant_id => '',
 webmoney_secret_key => '',

 smscoin_id => '',
 alertpay_email => '',
 ###############################

 next_upload_server_logic => 'encodings',

 banned_countries => '',

 player => 'jw8',

 player_audio => 'audio',

 player_ads_fadein => '5',

 caching_expire => '5',

 bad_referers => '(gkplugin|proxy)',

 m_n => '1',
 m_n_users => 'registered',
 m_n_max_links => '25',

 use_cloudflare_ip_header => '1',

 m_r => '1',

 srt_burn => '',

 tier_views_number => '1000',

 link_format_uppercase => '',

 embeds_money_percent => '50',

 search_public_only => '1',

 srt_convert_to_vtt => '',

 player_embed_dl_button => '1',

 ###

 login_fail_max_attemps => '3',
 login_fail_last_hours => '1',

 player_related => '0',

 player_show_title => '1',
 #m_r_hls => '',
 #m_r_dash => '',

 max_money_x_limit => '10',
 max_money_x_days => '5',

 truncate_views_daily => '',

 m_i => '',
 m_i_server => 'https://img.xvs.tt',

 embed_static => '',

 overload_no_hd => '',

 m_h_enc_order => '',

 fair_encoding_slots => '',

 alt_preset_max_queues => '50',

 delete_disk_time => '0',

 player_image => 'snapshot',

 byteseller_id => '',
 byteseller_secret => '',
 byteseller_post_url => '',

 highload_mode => '',
 highload_mode_auto => '0',

 srt_allow_anon_upload => '',

 mp4_preload => 'auto',

 adb_no_money => '1',
 premium_no_money => '1',

 player_overlay_text => '',

 embed_responsive => '',

 no_video_ip_check => '',

 # DMCA mod
 m_a => '1',
 m_a_delete_after => '12',
 m_a_lock_delete => '1',

 player_image_stretching => 'uniform',

 embed_disabled => '',

 embed_disable_noref => '',

 embed_disable_except_domains => '',

 embed_no_hd => '',

 player_logo_url => '',

 player_logo_link => '',

 player_logo_hide => '1',

 player_logo_position => 'top-right',

 player_logo_padding => '5',

 p2p_on => '',
 p2p_provider => 'self',
 p2p_min_host_out => '',
 p2p_min_views => '',
 p2p_min_views_30m => '',
 p2p_only_srvname_with => '',
 p2p_hours => '00|01|02|03|04|05|06|07|08|09|10|11|12|13|14|15|16|17|18|19|20|21|22|23',

 p2p_streamroot_key => '',
 p2p_peer5_key => '',

 mailgun_api_url => '',
 mailgun_api_key => '',

 no_referer_no_money => '',

 file_server_ip_check => '',

 force_disable_adb => '',

 player_about_text => 'XVideoSharing',
 player_about_link => '',

 bad_agents => '(XBMC|gkplugin)',

 m_5 => '',
 m_5_hours => '',
 m_5_captcha => '',

 m_6 => '1',
 m_6_clone => '1',
 m_6_direct => '1',

 srt_auto_enable => '1',

 # 1.9
 jw8_key => '64HPbvSQorQcd52B8XFuhMtEoitbvY/EXJmMBfKcXZQU2Rnn',

 sibpay_api_key => '',
 sibpay_secret => '',

 player_chromecast => '1',

 max_complete_views_daily => '3',

 email_html => '1',

 avatar_width => '100',
 avatar_height => '100',

 player_default_quality => '',

 hls_preload_mb => '8',

 m_a_hide_redirect => '',

 overload_no_transfer => '',
 overload_no_upload => '',

 login_captcha => '',

 alt_ads_mode => '',

 embed_disable_only_domains => '',

 m_3 => '',
 m_3_uploaded_days => '30',
 m_3_noviews_days => '10',
 m_3_serverdisk_min => '80',
 m_3_max_total_size => '100',

 m_q => '1',
 m_q_users => 'registered',
 m_q_max_streams_live => '3',
 m_q_allow_recording => '1',
 m_q_stop_invis_after => '',
 index_live_streams_on => '',
 index_live_streams_num => '',

 m_r_no_mp4 => '',

 srt_burn_font => 'Comic Sans MS',
 srt_burn_size => '24',
 srt_burn_margin => '15',
 srt_burn_color => '66FFFFFF',
 srt_burn_coloroutline => '66000000',
 srt_burn_blackbox => '',

 m_7 => '',
 m_7_video_noserver => '1',
 m_7_video_noproxy => '1',
 m_7_video_notor => '1',
 m_7_video_action => 'message',
 m_7_video_action_message_txt => 'Your IP was blocked',
 m_7_video_download1 => '1',
 m_7_video_embed => '1',
 m_7_money_noserver => '1',
 m_7_money_noproxy => '1',
 m_7_money_notor => '1',
 m_7_money_percent => '50',


 # 1.95
 force_disable_popup_blocker => '',

 allow_no_encoding => '1',

 expire_quality_name => 'n',
 expire_quality_access_reg => '',
 expire_quality_access_prem => '',

 no_ipcheck_mobile => '',
 no_ipcheck_ipv6 => '',

 m_7_stats => '',

 skip_uploader_priority => '0',

 dirlinks_allowed_referers => '',

 video_page_disabled => '',

 watch_require_recaptcha => '',
 watch_require_recaptcha_expire => '60',

 player_logo_fadeout => '3',
 player_logo_mode => 'video',

 vast_vpaid_mode => 'insecure',
 vast_preload => '1',

 enc_queue_notmp4_priority => '1',

 player_playback_rates => '1, 1.25, 1.5, 2',

 embed_alt_domain => '',

 noplay_from_uploader_encoder => '',

 m_w => '',
 vast_tag => 'https://www.videosprofitnetwork.com/watch.xml?key=47c0c3a2930e8a17e99d242457ec0bc3',
 #vast_tag => 'https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/single_ad_samples&ciu_szs=300x250&impl=s&gdfp_req=1&env=vp&output=vast&unviewed_position_start=1&cust_params=deployment%3Ddevsite%26sample_ct%3Dskippablelinear&correlator=',
 #vast_tag => 'https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=vmap&unviewed_position_start=1&cust_params=deployment%3Ddevsite%26sample_ar%3Dpremidpost&cmsid=496&vid=short_onecue&correlator=',
 vast_client => 'vast',
 vast_preroll => '1',
 vast_midroll => '1',
 vast_midroll_time => '15',
 vast_midroll_tag => '',
 vast_postroll => '1',
 vast_postroll_time => '2',
 vast_postroll_tag => '',
 vast_skip_mins => '0',
 vast_alt_ads_hide => '',

 ### 1.99 ###

 vjs_theme => 'sea',

 google_drive_api_key => '',

 email_validation_code => '0',

 player_logo_opacity => '0.7',

 player_forward_rewind => '1',

 vast_countries => '',

 max_fps_limit => '30',

 m_8 => '1',
 multi_audio_on => '1',
 default_audio_lang => 'eng',
 multi_audio_user_custom => '1',
 multi_audio_user_list => 'eng=English,rus=Russian,fre=French,ger=German,spa=Spanish,ita=Italian',

 m_n_instant_md5_upload => '1',

 allow_non_video_uploads => '1',

 max_upload_length_min => '300',
 min_upload_length_sec => '5',

 upload_limit_files_last24 => '999',

 srt_mass_upload => '1',

 m_i_cf_zone_id => '',
 m_i_cf_token => '',

 srt_burn_default_language => 'eng',

 fileserver_fonts => 'Arial, Arial Black, Candara Bold, Tahoma, Tahoma Bold, Verdana, Verdana Bold, MV Boli, Sylfaen, Comic Sans MS, FuturaMediumC, Helvetica Neue Bold, Lucida Grande Regular, Lucida Grande Bold, STIXGeneral-Regular, STIXGeneral-Bold, AdobeArabic Bold',

 player_default_audio_track => '',
 player_default_audio_sticky => '1',

 p2p_self_tracker_url => 'wss://tracker.openwebtorrent.com', #'wss://tracker.openwebtorrent.com'

 ticket_categories => 'General, Technical, Payments, Partnership',
 ticket_moderator_ids => '32|45',
 ticket_moderator_categories => 'General, Technical',
 ticket_email_user => '1',
 ticket_email_admin => '1',

 ### 2.0 ###

 views_tracking_mode2 => '',

 player_hidden_link => '',
 player_hidden_link_tear => '',

 #hls2 => '',

 vid_keep_orig_playable => '',

 vid_play_anon_o => '1',
 vid_play_reg_o => '1',
 vid_play_prem_o => '1',

 m_6_req_limit_day => '1000',

 vast_pauseroll => '',
 vast_pauseroll_tag => '',

 recaptcha3_pub_key => '',
 recaptcha3_pri_key => '',
 static_embed_recaptcha_v3 => '',

 download_orig_recaptcha_v3 => '',

 hls_proxy => '',
 hls_proxy_percent => '100',

 quality_letters => ['l','n','h','x'],
 quality_labels => {'o'=>'Original', 'l'=>'Low', 'n'=>'Normal', 'h'=>'HD', 'x'=>'UHD', 'p'=>'Preview'},
 quality_labels_full => {'o'=>'Original', 'x'=>'UHD quality', 'h'=>'HD quality', 'n'=>'Normal quality', 'l'=>'Low quality', 'p'=>'Preview version'},

 enc_priority_l => '3',
 enc_priority_n => '2',
 enc_priority_h => '1',
 enc_priority_x => '0',

 enc_queue_transcode_priority => '3',

 torrent_dl_speed_reg => '500',
 torrent_dl_speed_prem => '0',
 torrent_up_speed_reg => '10',
 torrent_up_speed_prem => '50',
 torrent_peers_reg => '10',
 torrent_peers_prem => '20',
 torrent_clean_inactive => '24',

 m_f_track_current => '',

 m_5_video_only => '',
 m_5_devtools_mode => '2',
 m_5_devtools_redirect => 'https://google.com',
 m_5_adb_mode => '1',
 m_5_adb_script => 'boxad.js',
 m_5_adb_delay => '1',
 m_5_adb_no_prem => '1',
 m_5_devtools_no_admin => '',

 alt_ads_title0 => 'Full Ads, 100% profit',
 alt_ads_title1 => 'Less Ads, 75% profit',
 alt_ads_title2 => 'Half Ads, 50% profit',
 alt_ads_title3 => 'Low Ads, 25% profit',
 alt_ads_title4 => 'No Ads, No profit',
 alt_ads_percent0 => '100',
 alt_ads_percent1 => '75',
 alt_ads_percent2 => '50',
 alt_ads_percent3 => '25',
 alt_ads_percent4 => '0',
 alt_ads_tags0 => 'ad1,ad2,ad3,vast',
 alt_ads_tags1 => 'ad1,ad2,vast',
 alt_ads_tags2 => 'ad1,vast',
 alt_ads_tags3 => 'vast',
 alt_ads_tags4 => '',

 ### 2.1 ###
 upload_server_selection => '',

 quality_labels_mode => '1',
 quality_labels_bitrate => '1',

 turbo_boost => '',

 enc_priority_time => '1',

 remember_player_position => '1',

 no_ipcheck_countries => 'RU',

 no_ipcheck_agent_only => '',

 m_5_disable_right_click => '',
 m_5_disable_shortcuts => '',

 save_source_raw_info => '',

 hls_speed => '',

 paypal2_url => '',
 paypal2_public_key => '',
 paypal2_private_key => '',

 ip_check_logic => 'no_mobiles',

 m_6_users => 'registered',
 m_6_users_spec => 'special',
 m_6_delete => '1',
 m_6_req_limit_min => '5',

 m_9 => '1',
 m_9_users => 'registered',
 m_9_override_id => '',

 m_3_hot_stats_last_hours => '6',
 m_3_hot_files_run => '10',
 m_3_hot_disk_max => '90',
 m_3_hot_max_filesize => '5000',
 m_3_hot_min_views => '30',

 hls_proxy_random_chance => '10',
 hls_proxy_min_out => '600',
 hls_proxy_min_views => '10',
 hls_proxy_last_hours => '2',
 hls_proxy_divider => '',

 downloads_money_percent => '40',

 plans_storage => '10.00=1000=30, 20.00=1000=90',

 my_views_enabled => '1',
 my_views_last_days => '7',

 # 2.2

 proxy_num_reg => '1',
 proxy_num_prem => '2',
 proxy_pairs_expire => '3',

 show_upload_srv_id => '1',

 max_folders_limit_reg => '3',
 max_folders_limit_prem => '50',

 m_y => '',
 m_y_users => 'special',
 m_y_cf_auth_email => '',
 m_y_cf_auth_key => '',
 m_y_cf_account_id => '',

 player_color => '',

 jw8_skin => '',

 cdn_version_num => '1',

 disable_anon_payments => '1',

};

1;
