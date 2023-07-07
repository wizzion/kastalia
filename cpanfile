requires "Dancer2";

recommends "YAML"             => "0";
recommends "URL::Encode::XS"  => "0";
recommends "CGI::Deurl::XS"   => "0";
recommends "HTTP::Parser::XS" => "0";

on "test" => sub {
    requires "Test::More"            => "0";
    requires "HTTP::Request::Common" => "0";
};

requires 'Crypt::PasswdMD5'
requires 'Crypt::YAPassGen'
requires 'Dancer2'
requires 'Dancer2::Plugin::Ajax'
requires 'Dancer2::Plugin::Database'
requires 'Dancer2::Session::Memcached'
requires 'HTML::Strip'
requires 'Net::LDAP'
requires 'Pg::hstore'
requires 'Plack'
requires 'Plack::Handler::Starman'
requires 'URI::Encode'
requires 'plackup'
requires 'Plack::Handler::Starman'
requires 'install Net::LDAP'
requires 'JSON::XS'
requires 'Keyword::Pluggable'
requires 'Template::Plugin::ListUtil'
requires 'Text::CSV'
