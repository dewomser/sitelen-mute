#!/usr/bin/env perl
# Copyright (C) 2022  Alex Schroeder <alex@gnu.org>

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

use utf8;
# apply before loading Test::More
use open ':std', ':encoding(utf8)';
use Test::More;
use Modern::Perl;
use Config;
use File::Copy;
use File::Copy::Recursive qw(dircopy);
use File::Path qw(remove_tree);
use File::SearchPath qw(searchpath);
use File::Slurper qw(read_text read_binary);
use File::Spec::Functions qw(catfile);
use JSON::Tiny qw(decode_json);
use Mojo::DOM58;

plan skip_all => "'convert' not installed"
    unless searchpath('convert');

my $options = " -v -v";
# -o means without auto-orient
$options .= " -o" unless searchpath('exiftran') or searchpath('exifautotran');
# -no-sRGB means without intermediate sRGB colorspace conversion
$options .= " --no-sRGB" unless searchpath('tificc');
# -d means without zip
$options .= " -d" unless searchpath('zip') or searchpath('7za');

# where the images are
my $album = catfile("t", "album");
# where the gallery is generated
my $gallery = catfile("t", "gallery");
remove_tree($gallery) if -d $gallery;
my $json = catfile($gallery, "data.json");
my $html = catfile($gallery, "index.html");

# generate album
my $perl = $^X;
my $script = catfile("blib", "script", "sitelen-mute");
my $output = qx("$perl" "$script" -c txt $options "$album" "$gallery");
unlike($output, qr(error)i, "Running script");
like($output, qr(Processing 4 image files), "Proccessing files");
ok(-d $gallery, "Gallery was created");
ok(-f $json, "data.json was created");
ok(-e catfile($gallery, "imgs", "Blaufußtölpel.jpg"), "Blue-Footed Booby");
ok(-e catfile($gallery, "imgs", "P3111190.jpg"), "Marine Iguana");
ok(-e catfile($gallery, "imgs", "P3111203.jpg"), "Red Rock Crab");

# data
my $data = decode_json(read_binary($json));
is($data->{data}->[0]->{caption}->[0], "Zwei Blaufußtölpel beim Balztanz", "Caption title from text file");
is($data->{data}->[0]->{img}->[0], "imgs/Blaufußtölpel.jpg", "Filename of the blue-footed booby image in the JSON");
is($data->{data}->[0]->{date}, "2020-02-29 16:36", "Date of the blue-footed booby image in the JSON");
is($data->{data}->[1]->{caption}->[0], "The white stuff is salt", "Caption title from text file");
is($data->{data}->[1]->{img}->[0], "imgs/P3111190.jpg", "Filename of the marine iguana image in the JSON");
is($data->{data}->[1]->{date}, "2020-03-11 16:47", "Date of the marine iguana image in the JSON");
is($data->{data}->[2]->{caption}->[0], "Grapsus grapsus atop a marine iguana", "Caption title from text file");
is($data->{data}->[2]->{img}->[0], "imgs/P3111203.jpg", "Filename of the red rock crab image in the JSON");
is($data->{data}->[2]->{date}, "2020-03-11 16:54", "Date of the marine iguana image in the JSON");
is($data->{data}->[3]->{caption}, undef, "Caption title from text file");
is($data->{data}->[3]->{img}->[0], "imgs/head.jpg", "Filename of the third image in the JSON");
is($data->{data}->[3]->{date}, undef, "Date of the third image in the JSON");

my $dom = Mojo::DOM58->new(read_text($html));
is($dom->at("#wrapper a#0")->attr("href"), "imgs/Blaufußtölpel.jpg", "Blue-Footed Booby image href");
is($dom->at("#wrapper a#1")->attr("href"), "imgs/P3111190.jpg", "Marine Iguana image href");
is($dom->at("#wrapper a#2")->attr("href"), "imgs/P3111203.jpg", "Red Rock Crab image href");
is($dom->at("#wrapper a#3")->attr("href"), "imgs/head.jpg", "PNG Logo image href");
is($dom->at("#wrapper a#0")->attr("title"), "Zwei Blaufußtölpel beim Balztanz", "Blue-Footed Booby image title");
is($dom->at("#wrapper a#1")->attr("title"), "The white stuff is salt", "Marine Iguana image title");
is($dom->at("#wrapper a#2")->attr("title"), "Grapsus grapsus atop a marine iguana", "Red Rock Crab image title");
is($dom->at("#wrapper a#3")->attr("title"), "head.jpg", "PNG Logo image title");
is($dom->at("#wrapper a#0 img")->attr("alt"), "Zwei Blaufußtölpel beim Balztanz", "Blue-Footed Booby image alt text");
is($dom->at("#wrapper a#1 img")->attr("alt"), "The white stuff is salt", "Marine Iguana image alt text");
is($dom->at("#wrapper a#2 img")->attr("alt"), "Grapsus grapsus atop a marine iguana", "Red Rock Crab image alt text");
is($dom->at("#wrapper a#3 img")->attr("alt"), "head.jpg", "PNG Logo image alt text");

# a copy of the album: no changes
my $album2 = catfile("t", "album2");
remove_tree($album2) if -d $album2;
dircopy $album, $album2;
$output = qx("$perl" "$script" $options "$album2" "$gallery");
unlike($output, qr(error)i, "Running script again");
like($output, qr(None of the 4 found image files are new), "No new files");
like($output, qr(None of the images in the gallery were deleted), "No deleted files");

# data
$data = decode_json(read_binary($json));
is($data->{data}->[1]->{caption}->[0], "The white stuff is salt",
   "Caption title from text file, unchanged");

# removing a picture and updating
unlink(catfile($album2, "P3111190.JPG"));
$output = qx("$perl" "$script" $options "$album2" "$gallery");
unlike($output, qr(error)i, "Running script again");
like($output, qr(1 image in the gallery was deleted), "Marine Iguana image removed");
like($output, qr(Removed 1 image files from .*album.zip), "Marine Iguana image removed from zipfile");
ok(! -e catfile($gallery, "imgs", "P3111190.jpg"), "Marine Iguana image gone");
ok(-e catfile($gallery, "imgs", "P3111203.jpg"), "Red Rock Crab image there");
my $zipfile = catfile($gallery, "files", "album.zip");
my $dir = qx(unzip -l "$zipfile");
unlike($dir, qr(P3111190), "Marine Iguana image gone");
like($dir, qr(P3111203), "Red Rock Crab image there");

# data
$data = decode_json(read_binary($json));
is($data->{data}->[1]->{caption}->[0], "Grapsus grapsus atop a marine iguana",
   "Caption title from text file, the other one");
is($data->{data}->[1]->{caption}->[1], "", "Caption description from text file, empty");

done_testing;
