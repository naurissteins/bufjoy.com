package Plugins::Player::Audio;
use strict;
use XFileConfig;

use vars qw($ses $c);

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player, $db ) = @_;
	return if $player ne 'audio';

  my ($extra_settings, $extra_js, @tracks, $extra_html_pre, @plugins, $js_code_pre, $html, $code);


  my (@sources, $sources_code);


	if($file->{direct_links})
	{
		for(@{$file->{direct_links}})
		{
			push @sources, qq[$_->{direct_link}];
		}
		$sources_code = join(', ', @sources);

	}

  # Get artist or file title
  my ($audio_title);

  $file->{download_link}||=$ses->makeFileLink($file);

  if($file->{audio_title} && $file->{audio_artist}) {
    $audio_title.=qq[
    <h1 class="lg:text-md md:text-md font-semibold text-gray-100"><a href="$file->{download_link}" target="_blank">$file->{audio_title}</a></h1>
    <h3 class="lg:text-md md:text-sm font-semibold text-gray-400"><a href="$file->{download_link}" target="_blank">$file->{audio_artist}</a></h3>
    ];
  } else {
    $audio_title.=qq[
    <h1 class="lg:text-md md:text-md font-semibold text-gray-100"><a href="$file->{download_link}" target="_blank">$file->{file_title}</a></h1>
    ];    
  }


  # Votes
  my $db = $ses->db;
	my $votes = $db->SelectARefCached(300,"SELECT vote, COUNT(*) as num FROM Votes WHERE file_id=? GROUP BY vote",$file->{file_id});
	for(@$votes)
	{
		$file->{likes}=$_->{num} if $_->{vote}==1;
		$file->{dislikes}=$_->{num} if $_->{vote}==-1;
	}
	$file->{likes}||=0;
	$file->{dislikes}||=0;

  $file->{views} = $file->{file_views}+$file->{file_views_full};

  my $locked;
  if($file->{file_status} eq 'LOCKED') {
    $locked=1;
  }

  # If the file is locked, display a message and disable the code
  if ($locked) {
    $html = "File was locked by administrator";
    $code = "";  # You can also put a minimal script here if needed
    return ($html, $code);
  }  

  my $user = $ses->getUser;
  my $user_vote = $db->SelectRow("SELECT vote FROM Votes WHERE file_id=? AND usr_id=?", $file->{file_id}, $ses->getUserId);

  my $vote_action = 'up';
  my $vote_title = "Like this!";
  if ($user_vote) {
      if ($user_vote->{vote} == 1) {
          $vote_action = 'down';
          $vote_title = "Don't like this!";
      }
  }

  my ($vote);
    $vote.=qq[
      <a href="#" onclick="return jah('/?op=vote&file_code=$file->{file_code}&v=$vote_action')" title="$vote_title">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 fill-indigo-400" viewBox="0 0 512 512"><path d="M47.6 300.4L228.3 469.1c7.5 7 17.4 10.9 27.7 10.9s20.2-3.9 27.7-10.9L464.4 300.4c30.4-28.3 47.6-68 47.6-109.5v-5.8c0-69.9-50.5-129.5-119.4-141C347 36.5 300.6 51.4 268 84L256 96 244 84c-32.6-32.6-79-47.5-124.6-39.9C50.5 55.6 0 115.2 0 185.1v5.8c0 41.5 17.2 81.2 47.6 109.5z"></path></svg>
      </a>  
    ];

  my ($genre);
    if ($file->{audio_genre}) {
      $genre.=qq[
          <span class="inline-flex items-center gap-x-1.5 rounded-full px-2 py-1 text-xs font-medium text-gray-300 bg-slate-800 mr-2">
            <svg class="h-1.5 w-1.5 fill-indigo-400" viewBox="0 0 6 6" aria-hidden="true">
              <circle cx="3" cy="3" r="3" />
            </svg>
            $file->{audio_genre}
          </span>    
      ];        
    }
  # Comments
  my $comments = $db->SelectARef("
      SELECT COUNT(c.cmt_id) as comment_count
      FROM Files f
      LEFT JOIN Comments c ON c.cmt_ext_id = f.file_id AND c.cmt_type = 1
      WHERE f.file_id = ?
      GROUP BY f.file_id
  ", $file->{file_id});

  my $comment_count = $comments->[0]->{comment_count} // 0;

  my $usr_player_bar = $db->SelectOne("SELECT usr_player_bar FROM Users WHERE usr_id=?",$file->{usr_id});
  my $usr_player_html;  # Declare a new variable for the conditional HTML content
    if ($usr_player_bar) {
      $usr_player_html.=qq[
          <div class="inline-flex items-center space-x-2">
              <div class="inline-flex items-center space-x-2 bg-gray-800 px-3 py-2 rounded-md">
                  <span class="text-gray-400 text-xs font-medium">$file->{vid_audio_bitrate} kbp/s</span>
              </div> 
              <div class="inline-flex items-center space-x-2 bg-gray-800 px-3 py-2 rounded-md">
                  <span class="text-gray-400 text-xs font-medium">$file->{file_size_mb}</span>
              </div> 
              <div class="inline-flex items-center space-x-2 bg-gray-800 px-3 py-2 rounded-md">
                  <span class="text-gray-400 text-xs font-medium">$file->{vid_audio_rate} Hz</span>
              </div>                               
          </div>    
      ];        
    }

  my $usr_comment_global = $db->SelectOne("SELECT usr_comment_global FROM Users WHERE usr_id=?",$file->{usr_id});
  my $comment_global_html;  # Declare a new variable for the conditional HTML content
  if ($usr_comment_global) {
    $comment_global_html = qq[
        <div class="inline-flex items-center space-x-2 bg-gray-800 px-3 py-2 rounded-md">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 fill-indigo-400" viewBox="0 0 512 512"><path d="M512 240c0 114.9-114.6 208-256 208c-37.1 0-72.3-6.4-104.1-17.9c-11.9 8.7-31.3 20.6-54.3 30.6C73.6 471.1 44.7 480 16 480c-6.5 0-12.3-3.9-14.8-9.9c-2.5-6-1.1-12.8 3.4-17.4l0 0 0 0 0 0 0 0 .3-.3c.3-.3 .7-.7 1.3-1.4c1.1-1.2 2.8-3.1 4.9-5.7c4.1-5 9.6-12.4 15.2-21.6c10-16.6 19.5-38.4 21.4-62.9C17.7 326.8 0 285.1 0 240C0 125.1 114.6 32 256 32s256 93.1 256 208z"/></svg>
            <span class="text-gray-300 text-xs font-medium">$comment_count</span>
        </div>  
    ];        
  } else {
    $comment_global_html = '';  # Ensure it's an empty string if not active
  }

$html=qq[$extra_html_pre

<div class="flex flex-col md:flex-row gap-8 mb-8">
    <div class="md:flex-shrink-0 md:min-w-[250px] min-w-full">
      <div class="relative aspect-[1/1] sm:aspect-[1/1] lg:aspect-square  lg:shrink-0">
        <img id="coverImage" alt="" class="absolute inset-0 h-full w-full rounded-lg bg-gray-900 object-cover">
        <div class="absolute inset-0 rounded-2xl ring-1 ring-inset ring-gray-900/10"></div>				  
      </div>
    </div>
    <div class="flex-grow">
    <div class="flex justify-between">  
      <div class="flex space-x-4 mt-6 items-center">
        <sapn id="play" class="text-white w-10 h-10 p-1.5 rounded-full ring-2 ring-indigo-500 bg-indigo-500 cursor-pointer">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="-1 0 24 24" stroke-width="1.5" stroke="currentColor" class=""> <path stroke-linecap="round" stroke-linejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z" /> </svg>
        </sapn>
        <div class="flex flex-col">
          $audio_title
         </div>
      </div> 
      <div class="inline-flex items-center space-x-1 text-xs">
        $genre 
      <div class="current-time text-gray-400 hidden">00:00</div>
      <div class="divider text-gray-600 hidden">/</div>
      <div class="total-time text-gray-400">$file->{vid_length_txt}</div>
    </div>
    </div>   
    
      <div class="mt-2 mb-1">
        <audio preload="none" id="$file->{file_id}" type="audio/mpeg"></audio>
        <div class="controls">
          <div class="waveform-container bg-[#374151]" id="waveform">
            <img id="waveformImage" class="w-full md:h-28 lg:h-28 ">
            <div class="progress-bar" id="progressBar"></div>
          </div>
          
        </div>   
      </div> 
    <div class="button">
        <div class="flex justify-between">
            <div class="inline-flex items-center space-x-2">
                <div class="inline-flex items-center space-x-2 bg-gray-800 px-3 py-2 rounded-md">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 fill-indigo-400" viewBox="0 0 384 512"><path d="M73 39c-14.8-9.1-33.4-9.4-48.5-.9S0 62.6 0 80V432c0 17.4 9.4 33.4 24.5 41.9s33.7 8.1 48.5-.9L361 297c14.3-8.7 23-24.2 23-41s-8.7-32.2-23-41L73 39z"/></svg>
                    <span class="text-gray-300 text-xs font-medium">$file->{views}</span>
                </div>
                <div class="inline-flex items-center space-x-2 bg-gray-800 px-3 py-2 rounded-md">
                    $vote
                    <span id="likes_num-$file->{file_id}" class="text-gray-300 text-xs font-medium">$file->{likes}</span>
                </div> 
          $comment_global_html             
            </div>
          $usr_player_html
        </div>              
    </div>          
    </div>  
  </div>

<style>
#waveform {
  position: relative;
  cursor: pointer;
  z-index: 1;
}
#progressBar {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background-color: #c084fc;
  z-index: -1;
}
</style>
];

$code=<<ENP
document.addEventListener('DOMContentLoaded', () => {
  const audio = document.getElementById('$file->{file_id}');
  // Set the source of the audio
  audio.src = '$sources_code';  
    // Set the source of the cover image
  const coverImage = document.getElementById('coverImage');
  coverImage.src = '$file->{video_thumb_url}';
  // Set the source of the waveform image
  const waveformImage = document.getElementById('waveformImage');
  waveformImage.src = '$file->{wave1_url}';  
  const playPauseBtn = document.getElementById('play');
  const currentTimeElement = document.querySelector('.current-time');
  const dividerElement = document.querySelector('.divider');   
  const waveform = document.getElementById('waveform');
  const progressBar = document.getElementById('progressBar');

  const playIcon = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class=""> <path stroke-linecap="round" stroke-linejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.348a1.125 1.125 0 010 1.971l-11.54 6.347a1.125 1.125 0 01-1.667-.985V5.653z" /> </svg>`;
  const pauseIcon = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class=""> <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 5.25v13.5m-7.5-13.5v13.5" /> </svg>`;

  playPauseBtn.addEventListener('click', () => {
    if (audio.paused) {
      audio.play();
      playPauseBtn.innerHTML = pauseIcon;
      // Show the current-time and divider when playing
      currentTimeElement.classList.remove('hidden');
      dividerElement.classList.remove('hidden');
      doPlay(); // Call doPlay function when audio starts
    } else {
      audio.pause();
      playPauseBtn.innerHTML = playIcon;
    }
  });

  waveform.addEventListener('click', (e) => {
    const clickX = e.offsetX;
    const waveformWidth = waveform.clientWidth;
    const duration = audio.duration;
    audio.currentTime = (clickX / waveformWidth) * duration;
  });

  audio.addEventListener('timeupdate', () => {
    const currentTime = audio.currentTime;
    const duration = audio.duration;
    const progressBarWidth = (currentTime / duration) * waveform.clientWidth;
    progressBar.style.width = progressBarWidth + 'px';
    // Update the current time display
    const currentTimeElement = document.querySelector('.current-time');
    currentTimeElement.textContent = formatTime(currentTime);    
  });

    // Helper function to format time in MM:SS
    function formatTime(seconds) {
    const minutes = Math.floor(seconds / 60);
    const secondsPart = Math.floor(seconds % 60);
    return padWithZero(minutes) + ':' + padWithZero(secondsPart);
    }

    // Helper function to pad time components with zero if needed
    function padWithZero(number) {
    return number < 10 ? '0' + number : number;
    }  
   
}); 

function doPlay()
{

  \$.get('$c->{site_url}/dl?op=view&file_code=$file->{file_code}&hash=$file->{ophash}&embed=$f->{embed}', function(data) {
    \$('#fviews').html(data);
  });  

}

ENP
;
       
	return($html,$code);
}

1;
