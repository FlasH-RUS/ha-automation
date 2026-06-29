# My Home Assistant automation

## Awning automation

Location: `packages/awning.yaml`.

This is a smart awning automation that extends and retracts the awning based on the sun
azimuth/elevation. It also respects a special Google calendar and keeps the awning closed
during events in it. This calendar is populated once a day from a MeteoSwiss forecast.

You don't need 24/7 access to your Home Assistant in order for this setup to work: it pauses itself for a day in case the awning is moved manually.

> [!WARNING]
> Scripts here have hardcoded entity IDs, etc. This means, they will require some tuning before adding
> to a new Home Assistant installation.

### Design

The whole things consists of two blocks:

- Awning automation itself
- Creation of "bad weather" calendar events based on the SwissMeteo forecast

#### Automation

- There is a Google calendar (ID: `calendar.markise`) events in which close the awning for their
  duration.
- The proposed awning end state is set by a binary sensor (ID: `awning_auto_state`) which tracks the Sun
  (built-in Home Assistant entity; ID: `sun.sun`) azimuth and elevation and absence of events in the aforementioned
  calendar.
- There's a multi-select input that defines how the physical awning reacts to the aforementioned binary
  sensor. Options are:
  - Auto: the awning is actuated to the binary sensor state.
  - Aus bis Morgen, Aus: the awning doesn't actuate to the binary sensor state.
    The only difference is that "Aus bis Morgen" becomes "Auto" at the next midnight (there's a separate
    auotmation; ID: `1774900581887`) while "Aus" stays until it is manually switched to another state.
- There's an automation (ID: `1774901348871`) that switched Auto --> Aus bis Morgen in case the awning was manually extended/retracted. Doesn't matter if it's from Home Assistant widget, another automation (e.g. Google Home) or a physical button.

  > [!IMPORTANT]
  > This is a safety net for Home Assistant loosing connectivity to Internet while still having access
  > to the awning. This way it's possible to make sure awning stays closed for a day.

- Finally, there's an automation (ID: `1775244947613`) that moves the awning.

#### Calendar "bad weather" blocks

> [!NOTE]  
> The built-in Home Assistant [Google Calendar](https://www.home-assistant.io/integrations/google/)
> integration can create calendar events but can't delete/update them. This limits this setup to only
> one run per day -- otherwise blocking events will be overlapping and eventually create a huge mess in
> the calendar.  
> Consequently, there's a constant challenge to find the right balance betwwen the latest possible
> forecast poll (as the later -- the more precise) and the convenience.

> [!IMPORTANT]
> The built-in Home Assistant [Google Calendar](https://www.home-assistant.io/integrations/google/)
> integration polls the calendar once every 15 min. This means, there may be corresponding delays in
> additions/removals of the current even.

- There's a template sensor (ID: `awning_forecast_data`) that every 10:00 polls your SwissMeteo forecast.
- There are several automations (IDs: random numbers, havent's unified it yet, sorry) that react to the change of this sensor and create events in the Google calendar for corresponding weather conditions: low temperatur, cloudy weather, precipitation and high winds.
- There's a watching automation for everything above that sends a notification (and turns off awning automation for today) in case of any forecast-related failure.

  > [!IMPORTANT]
  > This is another safety net to prevent awning opening not knowing that's a bad weather outside.

### Known problems

Statistical sensors used to smooth rapid weather changes to avoid frequent awning moves use `keep_last_sample` to
use the last avaialble value when there were no changes in the original sensor during the sliding window duration.
This is only used after restarts/configs reload as all the other time Swiss Weather integration provides updates
every 10 minutes.  

But apparently `keep_last_sample` doesn't work with `max_age`. As a result sliding window sensors are prone to
turning unavailable on HA system restart/config reload: see https://github.com/home-assistant/core/issues/153562.

### Installation

Prerequisites:

- Add your awning to your Home Assistant. This scripts were written for [Sonoff LAN](https://my.home-assistant.io/redirect/hacs_repository/?owner=AlexxIT&repository=SonoffLAN&category=Integration).
- Install [Swiss Weather](https://my.home-assistant.io/redirect/hacs_repository/?owner=izacus&repository=hass-swissweather&category=integration) Home AssistantCS integration and configure it.

Installation:

1. Copy the `packages` folder with all its contents under your Home Assistant `config` folder.
1. Review all scripts for external ID references; change them to your IDs.
1. Add the following lines to your Home Assistant `configuration.yaml`:

  ```yaml
  # This is needed to alert on automation failures
  system_log:
    fire_event: true

  homeassistant:
    packages: !include_dir_named packages
  ```

### Development

Deployment script is available at `deploy.sh`. It:

- Uploads YAML files that are consumed as is by your HA to the machine running it.
- Triggers YAML validation on the machine.
- Triggers YAML files reload on the machine.

#### Prerequisites

1. You should be able to log into the machine without a password. Make sure to run `ssh-copy-id user@$MACHINE_IP` before you start using the script.
1. Create the following task in you VSCode `.vscode/tasks.json` to streamline redeployment:

    ```
    {
      "version": "2.0.0",
      "tasks": [
        {
          "label": "Deploy & validate HA config",
          "type": "shell",
          "command": "./deploy.sh",
          "args": [
            "user", // User on the prod machine
            "1.2.3.4", // Prod machine address
            "/opt/docker/homeassistant/config/", // HA location on the prod machine
            "LONG-LIVED-HA-ACCESS-TOCKEN" // HA long-lived access tocken
          ],
          "options": {
            "cwd": "${workspaceFolder}"
          },
          "presentation": {
            "reveal": "always",
            "panel": "dedicated",
            "clear": true,
            "showReuseMessage": false,
            "focus": true
          },
          "problemMatcher": []
        }
      ]
    }
    ```

1. Create a button on the status bar to trigger the task by adding the following to your `.vscode/settings.json` ([VsCode Action Buttons](https://marketplace.visualstudio.com/items?itemName=seunlanlege.action-buttons) extension is required):

   ```
   {
     "actionButtons.commands": [
       {
         "name": "$(cloud-upload) Deploy to Pi",
         "command": "workbench.action.tasks.runTask",
         "args": ["Deploy & validate HA config"],
         "useVsCodeApi": true,
         "color": "#4caf50",
         "tooltip": "Sync config to Pi, validate YAML, and reload HA"
       }
     ]
   }

   ```

## Dashboards

I keep my custom dashboards UI-configured, so YNAB files here are mostly a backup/example.  
See comments in YNAB files for dashboard dependencies and other notes.
