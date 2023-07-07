#!/usr/bin/env perl

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Plack::Builder;

use Kastalia::Main;

builder {
    enable "Plack::Middleware::SimpleContentFilter",
        filter => sub {s/\R//;s/\R//; };
        #filter => sub { s/DOCTYPE/BUBU/g; };
    #$app;
    Kastalia::Main->to_app;
};
#CloudAtlas::Main->to_app;
