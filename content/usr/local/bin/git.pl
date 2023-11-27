#!/usr/bin/perl

use strict;
use warnings;

sub main {
	my $force = shift // 0;

	my $git_ssh_url = $ENV{GIT_CONFIG_STORE_SSH_URL} // die "Must give GIT_CONFIG_STORE_SSH_URL!";

	chdir('/config') or die "Error: cannot chdir to /config: $!";

	my $commit_message = 'Autocommit';
	my $do_commit;
	my $help;
	open( my $file, '<', "nag.xml" );
	while ( <$file> ) {
		/^[\s]*<git commit_message="(.*?)" do_commit="(.*?)" help="(.*?)"/ or next;
		$commit_message = $1;
		$do_commit = $2;
		$help = $3;
		last;
	}

	if ( !$do_commit ) {
		return 1 if !$force;
	} else {
		`sed -i '/git commit_message=/s/git.*/git commit_message="" do_commit="0" help="$help"\\/>/' nag.xml`;
	}

	$git_ssh_url =~ /@(.*?):(.*?)\// or die "Invalid git_ssh_url: [$git_ssh_url]";
	my $host = $1;
	my $port = $2;
	system("ssh-keyscan -p $port $host >> ~/.ssh/known_hosts");

	#
	# need to decide the master data local or remote
	#
	# if remote commits > 0 && ! git local -> remote
	# else -> local
	#

	my $is_local_git_exists = system("git rev-parse --is-inside-work-tree") ? 0 : 1;

	if ( !$is_local_git_exists ) {
		system("git init .");
		system("git remote add origin $git_ssh_url");
		system("git fetch --all");
	}

	my $remote_commit_count = `git rev-list --count remotes/origin/master`;

	if ( !$is_local_git_exists && $remote_commit_count > 0 ) {
		system("git clean -d -f .");
		system("git pull origin master");
	} else {
		system("git stash");
		system("git pull origin master");
		system("git stash pop");
		system("git add .");
		system("git commit -m '$commit_message'");
		system("git push origin +master:master");
	}

	return 0;
}

exit main(@ARGV);
