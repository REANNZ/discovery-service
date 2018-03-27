# Developing with the AAF Discovery Service

The discovery service works differently to most web applications: 

* It's [sinatra](http://sinatrarb.com) based
* Pages for the discovery process itself are pre-calculated and stored in Redis
* Other pages, such as resetting a remembered IdP, are dynamically generated

## Environment

You will require a ruby and redis installation on the machine you're developing
on. For developers on OSX rbenv and homebrew will assist here.

## Development process

1. Run `./bin/setup` to configure your local environment.
1. In the `development` directory you'll find an `entities.json` file which is
   an export from the AAF test SAML service from January 2018.
1. In test or production federation scenarios the discovery service would be 
   setup to pull from SAML service directly this is not practical for development
   purposes at the scale of IdP/SP instances we require.

   Instead we create a 'fake' SAML service by running a HTML file server. For
   developers on OSX this looks like the following in a secondary terminal:

   ```
   $ cd development
   $ python -m SimpleHTTPServer 8000
   ```
1. Within your `discovery_service.yml` file set your saml_service url value as
   follows:

   ```
   :url: http://localhost:8000/entities.json
   ```
1. Seed your local redis instance by running `bin/update_metadata.rb`.
1. Start the web app with `bundle exec unicorn`.
1. For changes to views, javascript or css you'll need to re-run
   `bin/update_metadata.rb` to have changes flow through to your browser.
   Failing to run an update can cause the browser to hang or not display
   content. Unicorn does not need to be restarted post update.

## Updating SAML Services export

This should probably happen from time to time. This must be undertaken if the 
SAML service API is changing.

Developers MUST use Test federation data for this purpose.

To download the latest data:

```
curl https://saml.test.aaf.edu.au/api/discovery/entities > entities.json
```
