#! /usr/bin/perl
use strict;
use warnings;
use Term::ANSIColor;

# From http://perlmaven.com/how-to-create-a-perl-module-for-code-reuse
# expect ttrts perl module in cwd
use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(abs_path($0)); 

# Use our ttrts perl library
use ttrts;

our $usage_text=<<TEXT;
NAME
	randomPlayer.pl

USAGE
	randomPlayer.pl PLAYER_ID [OPTIONS]

DESCRIPTION
	A very random perl AI for ttrts

TEXT

# Exit with usage if not given a number
scalar(@ARGV) or printf $usage_text and exit 1;

# Grab the player
our $player = $ARGV[0];
our $turn = 0;

our $gameName;
our $gameX;
our $gameY;

# If player is non-numeric
($player =~ m/\D+/) and printf $usage_text and exit 1;

# Give random orders to all units
sub OrderEverythingRandom
{
	my @myUnits = @_;

	my $commands = "";
	my @selection = ("F","L","R","A");

	foreach my $unit (@myUnits)
	{	
		my ($unitID) = ($unit =~ /UNIT:(\d+)/);
		$commands = $commands."ORDER:".$selection[rand(4)]." id:"."$unitID";
		$commands = $commands."\n";
	}
	return $commands;
}

# Show launch params
printf("Launching with player %i\n",$player);

# Stay looping the AI
while ( 1 )
{
	# Wait for turn file
	our $turnFile = GetTurnFile($turn);

	# Wait for the turn file
	printf("Waiting for %s\n", $turnFile);
	WaitForFile $turnFile;

	# Read in the game state from turnFile
	my @units = GetUnitsForTurn($turnFile);
	my ($gameName,$gameX,$gameY) = GetHeaderForTurn($turnFile);

	# Get units on my player
	my @myUnits = getUnitsOnPlayer($player,@units);

	# Generate some commands
	my $commands = OrderEverythingRandom(@myUnits);

	# At this point, print the game map
	PrintGameMap($gameX,$gameY,@units);

	if( scalar(@units) == 0 )
	{
		printf "Game was a draw!\n";
		exit 0;
	}	
	elsif( scalar(@myUnits) == scalar(@units) )  
	{
		printf "Game over, you win!\n";
		exit 0;
	}
	elsif( scalar(@myUnits) == 0 )  
	{
		printf "Game over, you lose!\n";
		exit 0;
	}

	OutputCommandsFile $turn,$player,$commands;

	$turn++;

}
