/*
https://github.com/rails/sprockets/blob/070fc01947c111d35bb4c836e9bb71962a8e0595/UPGRADING.md#manifestjs
https://nicedoc.io/rails/sprockets
https://schneems.com/2017/11/22/self-hosted-config-introducing-the-sprockets-manifestjs/
*/

//= link_tree ../images

//= link_directory ../javascripts
//= link_directory ../stylesheets
//= link_directory ../vendor .css
//= link_directory ../javascripts/datatables
//= link application.js

//= link_tree ../stylesheets/specific
//= link_tree ../stylesheets/specific/keywords

//= link_tree ../stylesheets/common
//= link_tree ../stylesheets/ui-lightness

//= link_tree ../javascripts/specific
//= link_tree ../javascripts/specific/keywords