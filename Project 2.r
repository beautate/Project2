# DTSC 2302 - Project 2
# Topic: Immigration
# Group Members: Rishi Challa, Khem Khadka, Joshua Hernandez, Aryan Anerao, Beau Tate
# NOTE: Information regarding variables, and hypotheses can be found in README.md

library(tidyverse)
library(ggthemes)
library(olsrr)
library(magick)
library(gifski)
library(gganimate)

# --------------------------------- Setup Variables ---------------------------------
# Review over these variables manually and set them when running the script

# Whether or not to merge the datasets - set to true only if CleanedData/project2CompleteDataset.csv
# does not already exist. If you do set this to true, make sure you've already ran `dataCleaning.py`
performCleaning = FALSE;

# Whether or not to run the stepwise regression - this should product the same output as the table listed
# in the comments below.
runStepwiseRegression = TRUE;

# Whether or not to create the graphs, all created graphs will be placed in `Graphs/`
# If set to TRUE when there are already graphs then the graphs will simply be rewritten
createGraphs = TRUE;

# Whether or not to create the animated graphs, all animated graphs will create a temporary folder
# and then delete that folder in order to create the animation.
# NOTE: ANIMATED GRAPHS IS VERY GPU INTENSIVE - SET TO FALSE UNLESS ABSOLUTELY NECESSARY
createAnimatedGraphs = FALSE;

# Whether or not to save graphs to a file - The `Graphs` folder must exist in the same directory as the R script
# if set to true.
saveGraphsToFile = FALSE;

# Whether or not to conduct the statistical analysis - The output of all the tests will already be in the comments
# below
conductStatisticalAnalysis = TRUE;

# --------------------------------- Data Cleaning ---------------------------------

# We should perform the data cleaning
if (performCleaning) {
	# Merge all the datasets together
	datasets = read.csv("CleanedData/datasets.csv") # Contains a list of all datasets required to be merged

	# First get the correlates data
	dataset = read.csv("Data/Project2CorrelatesData.csv")

	# Remove all columns except the following who's variables we will use:
	correlateCols = c("year", "state", "mood", "right2work", "pc_inc_ann", "povrate", "ccpi", "evangelical_pop",
		"nonwhite", "valueofagsect", "region", "budget_surplus_gsp", "dem_unified", "rep_unified", "pctlatinoleg",
		"hs_dem_in_sess", "hs_rep_in_sess", "hs_ind_in_sess", "sen_dem_in_sess", "sen_rep_in_sess", "sen_ind_in_sess")

	dataset = dataset[correlateCols]

	# Rename the correlates year and state columns since correlates uses a different naming scheme
	names(dataset)[names(dataset) == "year"] <- "Year"
	names(dataset)[names(dataset) == "state"] <- "State"

	# Loop through and merge all the datasets from the filenames
	for (filename in datasets$Filename) {
		dataset = merge(dataset, read.csv(filename), by = c("State", "Year"))
	}

	# Sum up the dependent variables to make a compositeScore
	dataset$Immigration.Composite.Score = dataset$Task.Force.Agreement + dataset$Cooperation.With.Detainers +
		dataset$EVerify.Mandates + dataset$English.Declared + dataset$Insurance.for.Unauth.Kids +
		dataset$Insurance.for.Unauth.Adults + dataset$Food.Assist.for.Immigrant.Kids + dataset$Food.Assist.for.Immigrant.Adults

	# Save the completed merged dataset as a separate csv
	write.csv(dataset, file = "CleanedData/project2CompleteDataset.csv", row.names = FALSE)
} else {
	# Cleaning has already been performed, just read in the already cleaned file
	dataset = read.csv("CleanedData/project2CompleteDataset.csv");
}

# --------------------------------- Stepwise Regression ---------------------------------

if (runStepwiseRegression) {
	# All Variables
	stepwiseRegressionModel = lm(Immigration.Composite.Score ~ mood + right2work + pc_inc_ann + povrate + ccpi + 
		evangelical_pop + nonwhite + valueofagsect + region + budget_surplus_gsp + dem_unified + rep_unified +
		pctlatinoleg + hs_dem_in_sess + hs_rep_in_sess + hs_ind_in_sess + sen_dem_in_sess + sen_rep_in_sess + sen_ind_in_sess,
		data = dataset)
	stepwiseRegressionResult = ols_step_both_p(stepwiseRegressionModel)
	print(stepwiseRegressionResult)

	"
	| Step | Variable          | R-Square | Adj. R-Square | C(p)      | AIC       | RMSE   |
	|------|-------------------|----------|---------------|-----------|-----------|--------|
	| 1    | `evangelical_pop` | 0.191    | 0.189         | 1263.7780 | 1988.7664 | 0.9988 |
	| 2    | `region`          | 0.233    | 0.231         | 1162.2700 | 1952.7828 | 0.9727 |
	| 3    | `hs_rep_in_sess`  | 0.265    | 0.261         | 866.6940  | 1599.5557 | 0.9381 |
	| 4    | `rep_unified`     | 0.291    | 0.287         | 816.5810  | 1579.9839 | 0.9219 |
	| 5    | `valueofagsect`   | 0.300    | 0.294         | 801.3050  | 1574.6542 | 0.9169 |
	| 6    | `dem_unified`     | 0.305    | 0.298         | 793.4080  | 1572.4138 | 0.9144 |
	| 7    | `mood`            | 0.294    | 0.284         | 686.5870  | 1425.5100 | 0.8996 |
	| 8    | `nonwhite`        | 0.299    | 0.289         | 679.1940  | 1424.3081 | 0.8970 |
	"

	# Finance Only
	stepwiseRegressionModel2 = lm(Immigration.Composite.Score ~ pc_inc_ann + ccpi + budget_surplus_gsp + povrate, data = dataset)
	stepwiseRegressionResult2 = ols_step_both_p(stepwiseRegressionModel2)
	print(stepwiseRegressionResult2)
	"
	| Step | Variable             | R-Square | Adj. R-Square | C(p)      | AIC       | RMSE   |
	|------|----------------------|----------|---------------|-----------|-----------|--------|
	| 1    | `pc_inc_ann`         | 0.041    | 0.039         | 44.3670   | 1817.2938 | 1.0776 |
	| 2    | `povrate`            | 0.074    | 0.071         | 24.0210   | 1797.9712 | 1.0597 |
	| 3    | `budget_surplus_gsp` | 0.087    | 0.082         | 17.3330   | 1791.4748 | 1.0532 |
	"
}

# --------------------------------- Visualizations ---------------------------------

# Remove Scientific Notation
options(scipen = 10000)

"
Saves a plot and adds additional styling to it given a ggplot

args:
	graph (ggplot): The graph to save
	saveToFile (logical): Whether or not to save the graph to a file
	filename (character): The name of the file to save to
"
createPlot <- function(graph, saveToFile = FALSE, filename = "") {
	graph = graph + theme_fivethirtyeight() + theme(axis.title = element_text()) + scale_color_fivethirtyeight()
	if (saveToFile) {
		ggsave(filename = paste("Graphs/", filename, sep = ""), plot = graph, device = "png")
	}
	else {
		print(graph)
	}
}

"
Visualizes a single variable (Shows the distribution of it over time)
If staticGraph is set to false then any static graph arguments can be ommitted, same goes for animatedGraph.

args:
	variable (character): The name of the variable to visualize
	staticGraphFilename (character): The filename and path (.png) of the static graph
	animatedGraphFilename (character): The filename and path (.gif) of the animated grpah
	ylabel (character): The label description of the variable being visualized
	staticGraphSubtitle (character): The subtitle of the static graph
	staticGraphTitle (character): The title of the static graph
	animatedGraphTitle (character): THe title of the animated graph
	continious (logical): Whether or not the variable is continious
	removeStaticNA (logical): Removes all NAs before creating any static graphs if set to true
	staticGraph (logical): Whether or not to create the static graph
	animatedGraph (logical): Whether or not to create the animated graph
"
visualizeVariable <- function(saveGraphsToFile, variable, staticGraphFilename, animatedGraphFilename, ylabel, staticGraphSubtitle,
	staticGraphTitle, animatedGraphTitle, continious = TRUE, removeStaticNA = FALSE, staticGraph = TRUE, animatedGraph = TRUE) {
	# Boxplot
	if (staticGraph) {
		staticDataset = dataset
		if (removeStaticNA) staticDataset = filter(staticDataset, !is.na(dataset[[variable]]))

		if (continious) {
			graph = ggplot(staticDataset, aes(x = State, y = .data[[variable]])) + geom_boxplot() +
				xlab("State") + ylab(ylabel) + coord_flip() + labs(subtitle = staticGraphSubtitle) + ggtitle(staticGraphTitle)
		} else {
			graph = ggplot(staticDataset, aes(x = State, fill = factor(.data[[variable]]))) + coord_flip() + 
				geom_bar(stat = "count", position = "fill", na.rm = removeStaticNA) + xlab("State") + ylab("") +
				labs(subtitle = staticGraphSubtitle, fill = ylabel) + scale_y_continuous(breaks = NULL, labels = NULL) +
				ggtitle(staticGraphTitle)
		}

		createPlot(
			graph = graph,
			saveToFile = saveGraphsToFile,
			filename = staticGraphFilename
		)
	}

	if (!animatedGraph) return();

	# Animated Graph over Time
	filteredDataset = filter(dataset, !is.na(dataset[[variable]]))

	if (continious) {
		timeGraph = ggplot(filteredDataset, aes(x = State)) + coord_flip() +
			geom_bar(aes(y = .data[[variable]], fill = .data$State), stat = "identity", show.legend = FALSE) +
			xlab("State") + ylab(ylabel) + ggtitle(animatedGraphTitle) +
			labs(subtitle = "Showing Year {as.integer(frame_time)}") + theme_fivethirtyeight() +
			theme(axis.title = element_text(), legend.position = "none") + scale_color_fivethirtyeight() +
			transition_time(Year)
	}
	else {
		timeGraph = ggplot(filteredDataset, aes(x = State)) + coord_flip() +
			geom_bar(aes(fill = factor(.data[[variable]])), stat = "count", position = "fill") +
			xlab("State") + ylab("") + ggtitle(animatedGraphTitle) +
			labs(subtitle = "Showing Year {as.integer(frame_time)}", fill = ylabel) +
			theme_fivethirtyeight() + theme(axis.title = element_text()) + scale_color_fivethirtyeight() +
			transition_time(Year)
	}
	
	if (saveGraphsToFile) {
		# Saving images directly and joining them rather than using `anim_save` due to bug causing flickering and low resolutions
		duration = floor(length(unique(filteredDataset$Year)) / 5) # Duration of the anim is to be 5 years per second
		animate(timeGraph, nframes = duration * 60, duration = duration, device = "png",
			renderer = file_renderer("tempAnim", prefix = "tempAnimationImage", overwrite = TRUE))
		imgs <- list.files("tempAnim", full.names = TRUE)
		img_list <- lapply(imgs, image_read)
		img_joined <- image_join(img_list)
		img_animated <- image_animate(img_joined, fps = 20)
		image_write(image = img_animated, path = paste("Graphs/", animatedGraphFilename, sep = ""))
		unlink("tempAnim", recursive = TRUE)
	} else {
		print(timeGraph);
	}
}

# Evangelical Population Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "evangelical_pop",
	staticGraphFilename = "EvangelicalPopStaticGraph.png",
	animatedGraphFilename = "EvangelicalPopOverTime.gif",
	ylabel = "Evangelical Population (% of Population)",
	staticGraphSubtitle = "How do the Distributions of Evangelical Populations Look?",
	staticGraphTitle = "Evangelical Population Visualization",
	animatedGraphTitle = "Evangelical Population Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# Number of Republican state Representatives Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "hs_rep_in_sess",
	staticGraphFilename = "HsRepInSessStaticGraph.png",
	animatedGraphFilename = "HsRepInSessOverTime.gif",
	ylabel = "Number of Republican state Representatives",
	staticGraphSubtitle = "How do the Distributions of Republican Representatives Look?",
	staticGraphTitle = "Republican Representatives Visualization",
	animatedGraphTitle = "Republican Representatives Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# Is there a unified Republican Government Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "rep_unified",
	staticGraphFilename = "RepUnifiedStaticGraph.png",
	ylabel = "Is there a unified Republican Government? (1: Yes, 0: No)",
	staticGraphSubtitle = "How does the Distribution of Unified Republican Govts Look?",
	staticGraphTitle = "Unified Republican Government Visualization",
	continious = FALSE,
	removeStaticNA = TRUE,
	animatedGraph = FALSE,
	staticGraph = createGraphs
)

# US Agriculture Sector Value Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "valueofagsect",
	staticGraphFilename = "ValueofAgSectStaticGraph.png",
	animatedGraphFilename = "ValueofAgSectOverTime.gif",
	ylabel = "US Agriculture Sector Value added to US Economy",
	staticGraphSubtitle = "How much does the Agriculture Sector affect the Economy?",
	staticGraphTitle = "US Agriculture Sector Value Visualization",
	animatedGraphTitle = "US Agriculture Sector Value Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# Is there a unified Democrat Government Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "dem_unified",
	staticGraphFilename = "DemUnifiedStaticGraph.png",
	ylabel = "Is there a unified Democrat Government? (1: Yes, 0: No)",
	staticGraphSubtitle = "How does the Distribution of Unified Democrat Govts Look?",
	staticGraphTitle = "Unified Democrat Government Visualization",
	continious = FALSE,
	removeStaticNA = TRUE,
	animatedGraph = FALSE,
	staticGraph = createGraphs
)

# Stimson’s Policy Mood Measure Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "mood",
	staticGraphFilename = "MoodStaticGraph.png",
	animatedGraphFilename = "MoodOverTime.gif",
	ylabel = "Stimson’s Policy Mood Measure",
	staticGraphSubtitle = "What does the Distribution of the Mood Measure look like?",
	staticGraphTitle = "Mood Measure Visualization",
	animatedGraphTitle = "Mood Measure Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# Nonwhite-Population Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "nonwhite",
	staticGraphFilename = "NonwhiteStaticGraph.png",
	animatedGraphFilename = "NonwhiteOverTime.gif",
	ylabel = "Non-White Population",
	staticGraphSubtitle = "What does the Distribution Non-White Populations look like?",
	staticGraphTitle = "Non-White Population Visualization",
	animatedGraphTitle = "Non-White Populations Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# Per Capita Annual Income Visualization
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "pc_inc_ann",
	staticGraphFilename = "AnnualIncomeStaticGraph.png",
	animatedGraphFilename = "AnnualIncomeOverTime.gif",
	ylabel = "Per Capita Annual Income",
	staticGraphSubtitle = "What does the Distribution of Income look like?",
	staticGraphTitle = "Annual Income Visualization",
	animatedGraphTitle = "Annual Income Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# State Poverty Rate
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "povrate",
	staticGraphFilename = "PovertyRateStaticGraph.png",
	animatedGraphFilename = "PovertyRateOverTime.gif",
	ylabel = "State Poverty Rate",
	staticGraphSubtitle = "What does the Distribution Poverty look like?",
	staticGraphTitle = "Poverty Rate Visualization",
	animatedGraphTitle = "Poverty Rate Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# Budget surplus as pct. of GSP
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "budget_surplus_gsp",
	staticGraphFilename = "BudgetSurplusStaticGraph.png",
	animatedGraphFilename = "BudgetSurplusOverTime.gif",
	ylabel = "Budget surplus as % of GSP",
	staticGraphSubtitle = "What does the Distribution of Budget Surplus look like?",
	staticGraphTitle = "Budget surplus Visualization",
	animatedGraphTitle = "Budget surplus Over Time",
	staticGraph = createGraphs,
	animatedGraph = createAnimatedGraphs
)

# Immigration Composite Score Visualization (Dependent) - Animated
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "Immigration.Composite.Score",
	animatedGraphFilename = "ImmigrationCompScoreOverTime.gif",
	ylabel = "Immigration Composite Score (0-8)",
	animatedGraphTitle = "Immigration Friendliness Over Time",
	staticGraph = FALSE,
	animatedGraph = createAnimatedGraphs
)

# Immigration Composite Score Visualization (Dependent) - Static
visualizeVariable(
	saveGraphsToFile = saveGraphsToFile,
	variable = "Immigration.Composite.Score",
	staticGraphFilename = "ImmigrationCompScoreStaticGraph.png",
	ylabel = "Immigration Composite Score (0-8)",
	staticGraphSubtitle = "How Immigration Friendly are the States?",
	staticGraphTitle = "Immigration Friendliness Visualization",
	staticGraph = createGraphs,
	animatedGraph = FALSE,
	continious = FALSE
)

# --------------------------------- Analysis ---------------------------------

if (conductStatisticalAnalysis) {
	# H1.) In an analysis of states, there is a relationship between a state’s public finance (as measured by per capita income,
	#	the state’s CPI, and the poverty rate) and the disposition of its state level immigration legislation.

	linearModel1 = lm(Immigration.Composite.Score ~ pc_inc_ann + budget_surplus_gsp + povrate, data = dataset)
	summary(linearModel1)

	# H1a) The direction and strength of these relationships varies with demographic factors such as the state’s racial makeup, the
	# 	strength of labor unionization, the concentration of evangelical residents, and the citizens’ level of liberalism or
	# 	conservatism.
	linearModel2 = lm(Immigration.Composite.Score ~ pc_inc_ann + budget_surplus_gsp + povrate + evangelical_pop +
		region + hs_rep_in_sess + rep_unified + valueofagsect + dem_unified + mood + nonwhite, data = dataset)
	summary(linearModel2)

	# H2.) In an analysis of states, those that have higher levels of agricultural output are more likely to have state laws that are
	# 	friendly towards immigration. This need for agricultural workforce mitigates other political or financial factors that might
	# 	otherwise be the primary drivers of legislation towards immigration.
	linearModel3 = lm(Immigration.Composite.Score ~ valueofagsect, data = dataset);
	summary(linearModel3)

	# H3.) In an analysis of states, unified control of the government by one party has a relationship with state level immigration
	# 	legislation. Unified control by republicans has a negative relationship with pro-immigration policies whereas unified
	# 	control by Democrats has a positive relationship with pro-immigration policies.
	linearModel4 = lm(Immigration.Composite.Score ~ rep_unified + dem_unified, data = dataset)
	summary(linearModel4)

	# H4.) Within an analysis of states, when analyzing the demographic of state legislatures, states with a higher percentage of
	# 	latinx legislators have a positive correlation with pro-immigration policies. States with a low percentage of latinx
	# 	legislators have a positive correlation with anti-immigration policy. 
	linearModel5 = lm(Immigration.Composite.Score ~ pctlatinoleg, data = dataset)
	summary(linearModel5)
}