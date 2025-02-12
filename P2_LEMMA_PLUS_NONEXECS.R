# USED files:
#            full_geomerged_df.csv (from part 1: internal merge)
#            lemmatized_message.csv (from Jupyter "spacen met spacy" SpaCy)
#            lemmatized_title.csv (from Jupyter "spacen met spacy" SpaCy)
#            stopwords.txt
# 
# WRITE files:
#            for_spacy_message.csv 
#            for_spacy_title.csv 
#            full_geomerged_df_2.csv (for part 3)

library(tidytext)
library(dplyr)
library(qdap)




input <- read.csv("full_geomerged_df.csv")

brazil_df <- input
sanity_brazil <- input

brazil_df <- brazil_df %>%
  mutate(
    review_comment_message = as.character(review_comment_message),
    review_comment_title = as.character(review_comment_title)
  )

# --------------------------------- #
# Pre-Spacy Sentence-level cleaning #
# --------------------------------- #

# For message
brazil_df  <- brazil_df %>%
  mutate(
    # Remove punctuation 
    review_comment_message = gsub("[[:punct:]]+"," ", review_comment_message),
    # Remove digits
    review_comment_message = gsub("[[:digit:]]+"," ", review_comment_message),
    # remove double characters except ss and rr
    review_comment_message = gsub("([a-q t-z])\\1+", "\\1", 
                                  review_comment_message, 
                                  perl = TRUE),
    # Get rid of line break strings
    review_comment_message = gsub("\r?\n|\r", " ", review_comment_message)
  )

# for title
brazil_df  <- brazil_df %>%
  mutate(
    # Remove punctuation 
    review_comment_title = gsub("[[:punct:]]+"," ", review_comment_title),
    # Remove digits
    review_comment_title = gsub("[[:digit:]]+"," ", review_comment_title),
    # remove double characters except ss and rr
    review_comment_title = gsub("([a-q t-z])\\1+", "\\1", 
                                review_comment_title, 
                                perl = TRUE),
    # Get rid of line break strings
    review_comment_title = gsub("\r?\n|\r", " ", review_comment_title)
  )

# Remove extremely short comments except for "ok"
brazil_df <- brazil_df %>%
  mutate(
    review_comment_message = ifelse(
      nchar(review_comment_message) < 3 & review_comment_message != "ok",
      "",
      review_comment_message),
    
    review_comment_title = ifelse(
      nchar(review_comment_title) < 3 & review_comment_title != "ok",
      "",
      review_comment_title)
        )

# Convert to lower
brazil_df <- brazil_df %>%
  mutate(
    review_comment_message = tolower(review_comment_message),
    review_comment_title = tolower(review_comment_title)
  )

# Record comment length before transformations
brazil_df <- brazil_df %>%
  mutate(
    # total characters in the string
    bef_nchar = nchar(brazil_df$review_comment_message),
    # total number of separations (words) in the string 
    bef_nwords = lengths(strsplit(brazil_df$review_comment_message, " ")),
    # average number of letters per word 
    nchar_perword = nchar(brazil_df$review_comment_message) / lengths(strsplit(brazil_df$review_comment_message, " "))
  )

# write for "Spacen met Spacy.ipynb"
to_write_message <- brazil_df %>%
  select(review_id, review_comment_message)

to_write_title <- brazil_df %>%
  select(review_id, review_comment_title)

write.csv(to_write_message, "for_spacy_message.csv", row.names = FALSE)
write.csv(to_write_title, "for_spacy_title.csv", row.names = FALSE)

# ------------------- #
# Post-SpaCy cleaning #
# ------------------- #

# needed for merge 
brazil_df$index <- c(0: (nrow(brazil_df) - 1))

merg_func <- function(brazil_df, df, type){
  df <- df %>%
    select(-X)
  
  brazil_df <- merge(brazil_df, df, 
                     by.x = "index",
                     by.y = "index",
                     all.x = TRUE)
  
  return(brazil_df)
}

# Load data from "Spacen met Spacy.ipynb"
lemmatized_message <- read.csv("lemmatized_message.csv")
lemmatized_title <- read.csv("lemmatized_title.csv")

brazil_df <- merg_func(brazil_df, lemmatized_title, "title")
brazil_df <- merg_func(brazil_df, lemmatized_message, "message")

brazil_df <- brazil_df %>%
  mutate(review_comment_title = as.character(title),
         review_comment_message = as.character(message)) %>%
  select(-title, 
         -message)

# standardize comments to ASCII encoding representation
brazil_df <- brazil_df %>%
  mutate(
    # Convert message
    review_comment_message = iconv(
      review_comment_message, 
      to = "ASCII//TRANSLIT"),
    # Convert title
    review_comment_title = iconv(
      review_comment_title,
      to = "ASCII//TRANSLIT")
        )

# tidy text format shows word frequencies
text_df <- tibble(line = 1:nrow(brazil_df), 
                  text = as.character(brazil_df$review_comment_message))

new_text_df <- text_df %>%
  unnest_tokens(word, text) %>%
  count(word, sort = TRUE)


# ---------------------------------------- #
# individual word-level cleaning: prep dic #
# ---------------------------------------- #

dic <- vector()

# add word length column, needed for filtering super short words and stuff
new_text_df <- new_text_df %>%
  mutate(
    word_length = nchar(word)
  )

# df to capture the words
super_short_words <- new_text_df %>%
  filter(word_length < 3) 
# add to dic
dic <- c(dic, super_short_words$word)
# Moving forward, we can filter these out of the tidy df
new_text_df <- new_text_df %>%
  filter(!word_length < 3) 

# Words like "adoreiiiiiiiiiiii"
weird_words <- new_text_df %>%
  filter(grepl("([a-z\\d])\\1\\1", word))
# add to dic
dic <- c(dic, weird_words$word)
# Moving forward, we can filter these out of the tidy df
new_text_df <- new_text_df %>%
  filter(!grepl("([a-z\\d])\\1\\1", word))

# Words with no vowels
no_vowels <- new_text_df %>%
  filter(!grepl("[aeiou]+", word))
# add to dic
dic <- c(dic, no_vowels$word)
# Moving forward, we can filter these out of the tidy df
new_text_df <- new_text_df %>%
  filter(grepl("[aeiou]+", word))


# Words with only vowels
on_vowels <- new_text_df %>%
  filter(!grepl("[^aeiou]+", word))
# add to dic
dic <- c(dic, on_vowels$word)
# Moving forward, we can filter these out of the tidy df
new_text_df <- new_text_df %>%
  filter(grepl("[^aeiou]+", word))


# external stopwords document
port_stopwords <- read.table("stopwords.txt", sep = "", header=F)
# standardize them
port_stopwords <- port_stopwords %>%
  mutate(V1 = iconv(V1, to = "ASCII//TRANSLIT"))
# Keep nao
port_stopwords <- port_stopwords %>%
  filter(!grepl("nao", V1))
# add to dic
dic <- c(dic, port_stopwords$V1)

# Keep only unique elements in dic
dic <- unique(dic)

# ----------------------------------------------- #
# individual word-level cleaning: filter with dic #
# ----------------------------------------------- #

# message
empty_df <- as.data.frame(brazil_df$review_id)
empty_df$iterator <- c(1:nrow(empty_df))
empty_df$new_stuff <- 0 

iterator <- 1

for (i in brazil_df$review_comment_message) {
  print(paste(rm_stopwords(i, dic)[[1]], collapse = " "))
  empty_df$new_stuff[iterator] <- paste(rm_stopwords(i, dic)[[1]], collapse = " ")
  iterator = iterator + 1
}
brazil_df$review_comment_message <- empty_df$new_stuff

# title
empty_df <- as.data.frame(brazil_df$review_id)
empty_df$iterator <- c(1:nrow(empty_df))
empty_df$new_stuff <- 0 

iterator <- 1

for (i in brazil_df$review_comment_title) {
  print(paste(rm_stopwords(i, dic)[[1]], collapse = " "))
  empty_df$new_stuff[iterator] <- paste(rm_stopwords(i, dic)[[1]], collapse = " ")
  iterator = iterator + 1
}
brazil_df$review_comment_message <- empty_df$new_stuff

# ----------------------------------------------- #
# message + title column                          #
# ----------------------------------------------- #

brazil_df$message_and_title <- paste(brazil_df$review_comment_message,
                                     brazil_df$review_comment_title, 
                                     sep = " ")

brazil_df <- brazil_df %>%
  mutate(
    message_and_title = ifelse(
      is.na(review_comment_message) == FALSE & is.na(review_comment_title) == FALSE,
      paste(review_comment_message, review_comment_title, sep = " "), 0
                              ),
    message_and_title = ifelse(
      is.na(review_comment_message) == TRUE & is.na(review_comment_title) == FALSE,
      review_comment_title, message_and_title
                              ),
    message_and_title = ifelse(
      is.na(review_comment_message) == FALSE & is.na(review_comment_title) == TRUE,
      review_comment_message, message_and_title
                              ),
    message_and_title = ifelse(message_and_title == "0", NA, message_and_title
                              )
        )

write.csv(brazil_df,"full_geomerged_df_2.csv", row.names = FALSE)
