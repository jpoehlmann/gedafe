# Gedafe, the Generic Database Frontend
# copyright (c) 2000, 2001 ETH Zurich
# see http://isg.ee.ethz.ch/tools/gedafe

# released under the GNU General Public License

package Gedafe::Start;
use strict;

use vars qw(@ISA @EXPORT);
require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(Start);

use CGI 2.00 qw(-compile :cgi);

use Gedafe::Auth;
use Gedafe::Global qw(%g *u Global_InitUser);
use Gedafe::GUI;
use Gedafe::Util qw(MakeURL MyURL InitTemplate Template Error NextRefresh);

sub Start(%)
{
	my %conf = @_;

	my $q = new CGI;
	my $user = '';
	my $cookie;

	my %s = ( cgi => $q);

	if(defined $q->url_param('reload')) {
		%g = ();
	}

	# configuration
	if(not exists $g{conf}) {
		# defaults
		$g{conf} = {
			list_rows  => 10,
			admin_user => 'admin',
			tickets_socket => '/tmp/.gedafed.sock',
		};

		# init config
		while(my ($k, $v) = each %conf) {
			$g{conf}{$k}=$v;
		}

		# test mandatory arguments
		my @mandatory = ('templates', 'app_site','app_path');
		for my $m (@mandatory) {
			defined $g{conf}{$m} or
				die "ERROR: '$m' named argument must be defined in Start.\n";
		}

		# app_url
		$g{conf}{app_url} = "http://$g{conf}{app_site}$g{conf}{app_path}";
	}

	my $expires = defined $q->url_param('refresh') ? '+5m' : '-1d';

	InitTemplate("$g{conf}{templates}",".html");

	if(defined $q->url_param('reload')) {
		my $next_refresh=NextRefresh();
		print $q->header(-expires=>'-1d');
		print Template({
			PAGE => 'reload',
			ELEMENT => 'reload',
			THISURL => MyURL($q),
			NEXTURL => MakeURL(MyURL($q), { reload=>'', refresh=>$next_refresh }),
		});
		exit;
	}

	if($q->url() !~ "^$g{conf}{app_url}") {
		Error(\%s, "You accessed the wrong URL. Go <A href=$g{conf}{app_url}>here</>.");
	}

	GUI_CheckFormID(\%s, $user);

	my $dbh = AuthConnect(\%s, \$user, \$cookie) or do {
		Error(\%s, "Couldn't connect to database or database error.");
	};

	Global_InitUser($user);
	
	my $action = $q->url_param('action') || '';
	if($action eq 'edit' or $action eq 'add' or $action eq 'delete') {
		# cache forms...
		$expires = '+1d';
	}
	if($q->request_method() eq 'POST') {
		# do not cache POST requests, so that for "Duplicate Form" is
		# shown if needed...
		$expires = '-1d';
	}

	# header
	if(! $cookie) {
		print $q->header(-expires=>$expires);
	} else {
		print $q->header(-expires=>$expires,-cookie=>$cookie);
	}
	$s{http_header_sent}=1;

	GUI_PostEdit(\%s, $user, $dbh);

	if($action eq 'list') {
		GUI_List(\%s, $user, $dbh);
	}
	elsif($action eq 'listrep') {
		GUI_ListRep(\%s, $user, $dbh);
	}
	elsif($action eq 'edit' or $action eq 'add' or $action eq 'reedit') {
		GUI_Edit(\%s, $user, $dbh);
	}
	elsif($action eq 'delete') {
		GUI_Delete(\%s, $user, $dbh);
	}
	else {
		GUI_Entry(\%s, $user, $dbh);
	}

	$dbh->disconnect;
}

1;
