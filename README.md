---
title: "Open Source System Dynamics"
author: "Sally Thompson"
format: html
editor: visual

execute: 
  eval: true
---

A 'How to' guide to create a system dynamics model interface using open source software.

Takes an already-developed model built using Stella Architect (but the method is also applicable to models built in other software that follows the XMILE convention), and interacts with it in `R`, using the `reticulate` package to harness the power of the `ASDM` package developed for Python by Wang Zhao.

The `ASDM` package also has the ability to build from scratch but this guide does not cover that.

## Overview

The `reticulate` package allows you to run Python code in R. Python is more explicit than R about environments, and this can be tricky to navigate for a someone not familiar with Python. Therefore this guide will start with a light touch, using the default environment created when you install `reticulate`. It will then give details about how to set up a dedicated environment for each project, which will be necessary if you plan to build and deploy a `Shiny` app.

This guide takes a simple capacity-constrained Stella model, then uses the functionality of the ASDM package to load it into R, adjust parameters and run some simulations. These simulations are the equivalent of running the model in 'Stella Live' mode.

![](images/clipboard-1964936420.png)

The three inputs that the user will be able to adjust are coloured green: 'referrals per week' is a graphical, whilst 'total places' and 'length of service wks' are single values. If you have access to Stella, run this model so you can compare results.

### Initial Setup

All code is in `R` and can be worked from R Studio IDE.

Start by loading R libraries, and installing `reticulate`:

```{r libraries}

library(dplyr)
library(janitor)
library(ggplot2)

if(!require(reticulate)){
  install.packages("reticulate")
  }
```

At this stage just be aware that this will have created a virtual environment called `r-reticulate`.

Next is to check which version of Python you have installed:

```{r python-version}

library(reticulate)

py_config()
```

If you don’t have any versions of Python on your computer, you can install it using `install_python()`. If you need a specific version of Python insert it in the brackets, e.g.: `install_python("3.9.12")`

```{r install-python}
#| eval: false

install_python()
# install_python("3.9.12")
```

## Light Touch Approach

### Load Packages and Model

Start by loading the `ASDM` package. This uses a `reticulate` function to source a Python script.

```{r source-asdm}

source_python("asdm/asdm.py")
```

This might generate errors that some (Python) packages are missing. In that case run the following code, replacing 'NAME_1' etc with the package(s) listed in the error message, then re-run the `source_python()` line.

```{r py-install}
#| eval: false

# install python packages
py_install(c("NAME_1", "NAME_2", "NAME_3"))

source_python("asdm/asdm.py")
```

You should now see a number of objects in your global (R) environment.

Next load in the Stella .stmx file, and assign it a name:

```{r load-model}

pathway_model <- sdmodel(from_xmile = "capacity constrained service pathway.stmx")
```

### First Run

Run the model with the pre-populated data. `simulate()` is a python function from the ASDM package, being applied to the object `pathway_model`.

```{r simulate}

pathway_model$simulate()
pathway_model$summary()
```

Send the results to a dataframe:

library(janitor)

```{r results-run-1}

run_1 <- pathway_model$export_simulation_result(format='df',
                                            dt = TRUE, 
                                            to_csv = FALSE) |> 
  clean_names()
```

### **Second run - adjust single value parameters**

Before adjusting any parameters it is necessary to reset, by running `clear_last_run()`.

There are two inputs that each take a single value; these are adjusted using the `replace_element_equation()` function. The first argument is the parameter to be changed, the second is the new value.

In this example we will increase the total number of places from 130 to 150, and reduce length of service (in weeks) to 6.

Run the simulation, then save the results in a new dataframe.

```{r adjust-params}

pathway_model$clear_last_run()

pathway_model$replace_element_equation('total_places', 150)
pathway_model$replace_element_equation('length_of_service_wks', 6)
pathway_model$simulate()

run_2 <- pathway_model$export_simulation_result(format='df', 
                                            dt = TRUE,
                                            to_csv = FALSE) |> 
  clean_names()

```

#### Compare Results

Plot the results of each run to see that the model has updated. In this example we will see how the number of people waiting to start the service has changed.

```{r compare}



run_1 |> 
  ggplot(aes(x = time, y = waiting_to_start)) +
  geom_line(colour = "#000055") +
  geom_line(data = run_2, colour = "#aa0000") +
  theme_minimal()


```

### Third run - adjust graphical

The parameter 'referrals per week' is a graphical input, and so the function to alter this requires new y-values as a minimum (it is possible to supply new x-values also. What does `new_xscale` do?).

Note that the default behaviour is to interpolate between each point. Is it possible to have discrete values?

```{r adjust-graphical}

pathway_model$clear_last_run()

pathway_model$overwrite_graph_function_points(
  name = "referrals_per_week",
  new_ypts = c(15, 35, 40, 30)
)
pathway_model$simulate()

run_3 <- pathway_model$export_simulation_result(format='df', 
                                            dt = TRUE,
                                            to_csv = FALSE) |> 
  clean_names()

```

#### Compare results

Comparing the number of people waiting over the last two runs.

```{r}

run_2 |> 
  ggplot(aes(x = time, y = waiting_to_start)) +
  geom_line(colour = "#000055") +
  geom_line(data = run_3, colour = "#aa0000") +
  theme_minimal()

```

That concludes the very brief introduction to using ASDM to run Stella models in 'light touch' mode. In practice, you are more likely to develop this as a project, which may then be published. In this case more care is needed around setting up the environment.

## Project-based Approach

Python is very particular/explicit about environments. Whilst there is a lot of logic around this, it can make it tricky if you are new to Python. There is much advice on the internet, but this can be conflicting and confusing. What follows is one method that I have found to work, but by no means is it the only method (and I am sure there are better ones out there).

This method assumes you have already created a project within RStudio.

### Creating and pointing to the environment

The first step is to create a new virtual environment within your Rproject folder. Once you have run the code below, you should notice a new folder has been created. If you need to install any Python packages for this project, this is where they will be stored.

```{r}
#| eval: false

virtualenv_create(envname = "./.venv")
```

Next, you need to create (if it doesn't already exist), or add to, the project's `.Renviron` file to point to the version of Python that Reticulate will use.

To create this, select File -\> New File -\> Text File from the Menu.

Add the following code:

``` {RETICULATE_PYTHON=".venv/Scripts/python.exe"}
```

then 'save as' and give the file the name `.Renviron` (note the dot preceding the R). This is now specifically pointing Reticulate to the relevant version of Python to use, and will apply each time you open the R project folder.

### Loading ASDM

From this point on, the process is the same as above. The first time you run `source_python("asdm/asdm.py")` you may be prompted to install Python packages - this is because they don't yet exist in the new environment you just created. As before, running `py_install(c("NAME_1", "NAME_2", "NAME_3"))` will fix this.

## Making it interactive

Adding Python will add to the complexity of a project being developed primarily in R. Running individual lines of code to simulate and adjust parameters is useful for testing that the model is behaving as expected, but the real power of `ASDM` is being able to interact with a model in real time.

In this repo is a script that runs a simple Shiny app, with sliders to adjust the number of places and the length of service. Run it in RStudio to start to see how you might build capability into an open source interface.

<https://support.posit.co/hc/en-us/articles/360022909454-Best-Practices-for-Using-Python-with-RStudio-Connect>

<https://solutions.posit.co/write-code/reticulate/>
