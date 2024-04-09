#### simple shiny app to demonstrate using the Python package ASDM in R
# ASDM is being developed by Wang Zhao. More info at https://pypi.org/project/asdm/


library(dplyr)
library(tidyr)
library(janitor)
library(DT)
library(plotly)
library(reticulate)
library(shiny)

### set up ----

use_virtualenv('./.venv', required=TRUE)

# source ASDM python package
asdm <- import("ASDM")


# load stella model
pathway_model <- asdm$asdm$sdmodel(from_xmile = "capacity constrained service pathway.stmx")


# function to run a simulation and return results to a dataframe
run_sim <- function(mod){
    
    mod$simulate()
    res <- mod$export_simulation_result(format='df',
                                        dt = TRUE, 
                                        to_csv = FALSE)
    
    return(res)
}

#### Define UI for application ----
ui <- fluidPage(

    # Application title
    titlePanel("Open Source System Dynamics"),
    
    # Sidebar with slider inputs 
    sidebarLayout(
        sidebarPanel(
            
            sliderInput("places",
                        "Number of places:",
                        min = 0,
                        max = 300,
                        value = 130,
                        step = 5),
            
            sliderInput("los",
                        "Length of service (weeks):",
                        min = 0,
                        max = 12,
                        value = 7,
                        step = 0.25),
            
            hr(),
            
            p("Chart of weekly referral rate for reference"),
            
            plotlyOutput("pl_refs")
            
        ),

        # Show a plot of the generated distribution
        mainPanel(
            plotlyOutput("pl_flow"),
            plotlyOutput("pl_usage")
        )
    )
)

# Define server logic ----

server <- function(input, output) {
    
    ## update model based on silder and table inputs, return results
    
    update_model <- reactive({
        
        pathway_model$clear_last_run()
        pathway_model$replace_element_equation('total_places', input$places)
        pathway_model$replace_element_equation('length_of_service_wks', input$los)
  
        results <- run_sim(pathway_model) |> 
            clean_names()
        
        return(results)
        
    })
    
 
    
    ### outputs for UI ----
    
    output$pl_refs <- renderPlotly({
      update_model() |> 
        drop_na() |> 
        
        plot_ly(x = ~time, y = ~referrals_per_week, name = "Weekly referrals", 
                type="scatter", mode="lines", 
                line = list(color ="#5881c1")) |> 
                  layout(
                    hovermode = "x",
                    xaxis = list(title = "Days since simualtion start"),
                    yaxis = list(title = "Weekly referrals",
                                 rangemode = "tozero",
                                 hoverformat = ".0f")
                  )
    })
 
    output$pl_flow <- renderPlotly({
        update_model() |> 
            drop_na() |> 
            
            plot_ly(x = ~time, y = ~service_users, name = "Service Users", 
                    type="scatter", mode="lines", 
                    line = list(color ="#5881c1"),
                    stackgroup = 'one', fillcolor = "#d4dff0") |> 
            add_trace(y = ~unused_places, name = "Unused places", 
                      line = list(color= "#686f73"),
                      fillcolor= "#d8dadb") |> 
            add_trace(y =~waiting, name = "Waiting for service", 
                      line = list(color= "#ec6555"),
                      fillcolor= "#fbd7d3") |> 
            layout(
                hovermode = "x",
                xaxis = list(title = ""),
                yaxis = list(title = "Occupancy status",
                             rangemode = "tozero",
                             hoverformat = ".0f")
            )
        
    })
    
    output$pl_usage <- renderPlotly({
        update_model() |> 
            drop_na() |> 
            plot_ly(x = ~time) |> 
            add_lines(y = ~referrals,
                      name = "New referrals per day",
                      line = list(color ="#5881c1")) |>
            
            add_lines(y = ~finish_service, 
                      name = "Finish service", 
                      line = list(color= "#ec6555")) |> 
            
            layout(
                hovermode = "x",
                xaxis = list(title = ""),
                yaxis = list(title = "Daily flows in and out",
                             rangemode = "tozero",
                             hoverformat = ".1f")
            )
    })
    
}

# Run the application 
shinyApp(ui = ui, server = server)
