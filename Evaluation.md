# Evaluation Instructions

Once you have your development environment setup and you can access the Ignition Gateway Webpage, you're ready to create your demo project and complete the evaluation!

We'll refer to a few constructs in the remainder of the guide:

| Name                | Description                              |
| ------------------- | ---------------------------------------- |
| Gateway Web Page    | Hosted on Port 8088 of the Ignition Gateway |
| Gateway Status Page | This is the *Status* page off of the *Gateway Web Page* |
| Gateway Home Page   | This is the *Home* page off of the *Gateway Web Page* |
| Gateway Config Page | This is the *Configuration* page off of the *Gateway Web Page* |
| Designer            | Primary Application Development Environment for Ignition |
| Project             | One or more projects can exist on an Ignition Gateway server |
| Client              | Web-Launched Client for a given Ignition Project |

## Setting up Device and Database Connections

Before we actually dive into the creation of a GUI application, we'll get some preliminary items setup.

1. Create/Configure a database connection called `ignition`.  The connection should use MySQL against the `ignition` database with username `ignition` and password `ignition`.
2. Create/Configure two *Generic Simulator* devices, one named `Device1`, another named `Device2`.

The Gateway status page should now reflect the new database connection and simulated devices:

![Database and Devices Created](images/Database and Devices Created.png)

## Setting up Alarm Journaling and Project Auditing

In order to make sure we can view some trended data from our simulated devices in our project, lets also setup our history connections:

1. From the *Gateway Config Page*, configure a new Alarm Journal profile called `Journal` against our `ignition` database we created in the last section.

2. Also create an Audit Profile called `Audit` within the `ignition` database as well.  Adjust the table name to be the lowercase `audit_events` for consistency with other Ignition default table names.

## Creating an Application

Next, we're going to create a baseline application to house our visualization and tag definitions:

1. Use the *Launch Designer* link on the *Gateway Web Page* to open the Designer.
2. Create a project called `Evaluator` using one of the *Single-Tier* navigation templates that will provide us with menuing and navigation preconfigured.
3. Adjust the project properties to utilize *Anchored* mode as the default component layout methodology.

Lets perform some customizations and prepare a new window for our evaluation:

1. Create a new *Main Window* in the `Main Windows` folder called `Demo`.

2. Open the `Navigation` window from the *Project Browser*.

3. Remove the Ignition logo element and replace with the Evaluator Logo image:
   ![Evaluator Logo](images/Evaluator Logo.png)

   > Probably should utilize *Anchored* layout on your new image element so that it always will show up on the left-hand side of the menu!

4. Use the *Tab Strip Customizer* on the `Tabs` element to add a new tab called `Demo` for window we created above.

   > It should be placed in between the `Overview` and `User Management` tabs

5. Save and close the `Navigation` window.


We need some tags in order to drive our displays, so lets create some:

1. Bring up the OPC Browser against the internal `Ignition OPC-UA Server`.  Add the entire `Devices` folder to the tags in the default provider for the project by just dragging the folder onto the `Tags` folder in the *Tag Browser*.
2. Adjust the `Default Historical` scan class to utilize a faster *Slow Rate* of `1000`ms so our history capture will be a little speedier.
3. Enable History on the `Realistic/Realistic0` and `Writable/WriteableDouble1` tags for both `Device1` and `Device2`. 
4. Modify the metadata on `Writeable/WriteableDouble1` on each device to allow for Engineering Units range from `-100` to `100`.
5. Enable a `Hi Alarm` on `Realistic/Realistic0` that activates when its value exceeds `15` for `Device1` and `20` for `Device2`

Now that we have some data, lets get started with our `Demo` window:

1. Open the `Demo` window and add an *Easy Chart* component to the screen.  

2. Configure the *Easy Chart* you created to have 2 subplots.  One of the subplots should have the `Realistic/Realistic0` and `Writeable/WriteableDouble1` tags from `Device1`, the other subplot should have the same tags from `Device2`.

   > Use a dark gray line for the `Realistic/Realistic0` values and a colored line (of your choosing) for the `Writeable/WriteableDouble1` tags.
   >
   > While you can edit the datasets of the *Easy Chart* manually, feel free to use the *Easy Chart Customizer* feature to make these additions.

3. Also configure the *Easy Chart* to utilize *Realtime* mode.  Disable *Pen Control?* to hide the configured pens listing.

4. Let's also add *Numeric Label* components so we can visualize the `Realistic/Realistic0` and `Writeable/WriteableDouble1` tags from `Device1` and `Device2`.  Name the components and lay them out in a reasonable manner of your choosing.

5. Modify the *Numeric Label* components you created to have the *Background Color* change to orange when the `AlertActive` property is true on `Realistic/Realistic0` (for each respective device). 

6. For the benefit of our users, lets also add some *Label* components to provide a description to the left of those *Numeric Label* components we added above.  Set the label contents accordingly.

   > You can also leverage *Container* components to group other components together.  Try experimenting with the border styles of the *Container* components to add decorative groupings to your application!

7. Finally, add a button (for each of the value pairs we created above) that will set the `Writeable/WriteableDouble1` tag with the value of `Realistic/Realistic0` from each device.  Set the button text to indicate that it will snapshot the associated device.

   > Once you configure the button for the *Set Tag Value* action, take a look at the *Script Editor* tab to see what it created.  You might see if you can leverage the `system.tag.read()` function to read the value directly from the tag instead of from a property.

8. Work with the layout features of the components you've created to make this window function properly on any size screen.  Consult the the documentation here for more information on layout: [Component Layout](https://docs.inductiveautomation.com:8443/display/DOC79/Working+with+Components#WorkingwithComponents-ComponentLayout)

9. Save and close your `Demo` window.  

10. Save and Publish the application.  Then try previewing the project via the Designer's *Tools->Launch Project* menu.

Once complete, you should have a window that will allow viewing some of the simulated values as well as the snapshot values (which should change when you click the snapshot button you created).

## Submitting your Project

When you're satisfied with the state of your project, utilize the *Gateway Config Page* under the *System->Backup/Restore* section to download a Gateway Backup.  Post to your favorite cloud service and send a link to your ENE representative for evaluation!

Thank you for your efforts and we hope you enjoyed this small introduction to one of the many platforms you'll experience as an SI!