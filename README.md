# Automatic Data Classification using OpenAI, PostgreSQL, pgai, and pgvector

Data classification is the process of categorizing data into different classes or categories based on certain criteria. With the ever-increasing volume of data being generated, it has become essential to classify data to make it more manageable, searchable, and secure. By categorizing data, organizations can streamline their data management processes, improve data security, and enhance data analysis capabilities. In this tutorial, we will explore how to perform automatic data classification using OpenAI, PostgreSQL, pgai, and pgvector. Normally these data classification tasks are done using some RAG frameworks like LangChain or Llama-Index but that increases the complexity of the system and also means compromising on the data security. What is you don't have to compromise on the data security and still get the benefits of the RAG framework? That's where the pgai and pgvector comes into play. pgai brings the LLMs closer to the data, removing the dependency on the multiple frameworks and also providing the data security. 

In this tutorial, we will demonstrate how to perform automatic data classification using OpenAI, PostgreSQL, pgai, and pgvector. OpenAI is a leading artificial intelligence research lab that has developed powerful language models such as GPT-3. PostgreSQL is a popular open-source relational database management system that provides advanced features for data storage and retrieval. pgai is an extension for PostgreSQL that enables developers to interact with OpenAI's API or any other AI model directly from the database. pgvector is an extension for PostgreSQL that provides support for vector data types and efficient similarity search capabilities. By combining the power of PostgreSQL, pgai, pgvector, and OpenAI, you can build an automated data classification system that can classify text data based on certain criteria.

Without further ado, let's get started with the tutorial!

# Installation and Setup

The easiest way to get started with the pgai extension is to use a pre-built Docker container. You can pull the latest version of the pgai Docker image and get started with the extension in minutes. This installation method has two prerequisites: Docker and PostgreSQL. If you don't have Docker or PostgreSQL installed on your system, you can follow the instructions in the next section to install them.

Follow the steps mentioned in https://docs.docker.com/engine/install/ to install Docker on your system.

You can install PostgreSQL using the following commands:
```bash
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -`
sudo apt-get update
psql --version
```

Once you have Docker and PostgreSQL installed on your system, you can pull the latest version of the pgai Docker image using the following command:
```bash
sudo apt update
docker pull timescale/timescaledb-ha:pg16
```

# Running the Docker Container
After pulling the pgai Docker image, you can run a Docker container with the pgai and pgvector extensions enabled. You can use the following command to run the container:
```bash
docker run -d --name timescaledb -p 5432:5432 -e POSTGRES_PASSWORD=password timescale/timescaledb-ha:pg16
```

Now that the Docker container is running, you can get inside the container with the following command:
```bash
docker exec -it timescaledb /bin/bash
```

Since we will be using OpenAI's API to classify product reviews, you will need to set your OpenAI API key as an environment variable. You can do this by running the following command:
```bash
export OPENAI_API_KEY="{API_KEY}"
```

Once the OpenAI API key is set as an environment variable, you can connect to the PostgreSQL database running inside the Docker container using the following command:
```bash
PGOPTIONS="-c ai.openai_api_key=$OPENAI_API_KEY" psql -d "postgres://postgres:password@localhost/postgres"
```

Great! You now have a Docker container running we will now activate the pgai and pgvector extensions in the PostgreSQL database running inside the container.
```sql
CREATE EXTENSION IF NOT EXISTS ai CASCADE;
CREATE EXTENSION IF NOT EXISTS vector CASCADE;
```

Let's now check if the pgai and pgvector extensions are enabled in the PostgreSQL database by running the following command:
```sql
\dx
```

Output:
```bash
                                                    List of installed extensions
        Name         | Version |   Schema   |                                      Description                                      
---------------------+---------+------------+---------------------------------------------------------------------------------------
 ai                  | 0.3.0   | public     | helper functions for ai workflows
 plpgsql             | 1.0     | pg_catalog | PL/pgSQL procedural language
 plpython3u          | 1.0     | pg_catalog | PL/Python3U untrusted procedural language
 timescaledb         | 2.15.3  | public     | Enables scalable inserts and complex queries for time-series data (Community Edition)
 timescaledb_toolkit | 1.18.0  | public     | Library of analytical hyperfunctions, time-series pipelining, and other SQL utilities
 vector              | 0.7.2   | public     | vector data type and ivfflat and hnsw access methods
(6 rows)
```

# Data Classification Directly on Reviews Column of the product_reviews Table using pgai and OpenAI API
Data classification is the process of categorizing data into different classes or categories based on certain criteria. In this tutorial, we will use the pgai extension to classify product reviews into positive, negative, or neutral categories using the OpenAI API. We will be provided with list of product reviews and our goal is to classify each review into one of the three categories: positive, negative, or neutral.

## Creating the `product_reviews` Table
The following SQL command creates a table named `product_reviews` to store customer product reviews. The table includes columns for customer ID, date of the review, product name, a short review, and a detailed review.

```sql
-- Create the `product_reviews` table
CREATE TABLE product_reviews (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    date TIMESTAMPTZ,                     -- Timestamp with timezone for the review date
    product TEXT,                         -- Name of the product being reviewed
    short_review TEXT,                    -- A brief summary of the review
    review TEXT                           -- The detailed review text
)
;
```

Let's confirm that the `product_reviews` table has been created successfully by running the following command:
```sql
\dt
```

Output:
```bash
              List of relations
 Schema |      Name       | Type  |  Owner   
--------+-----------------+-------+----------
 public | product_reviews | table | postgres
(1 row)
```

## Inserting Sample Product Reviews
Great! The `product_reviews` table has been created successfully. We will now insert some sample product reviews into the table to demonstrate the data classification process. The following SQL command inserts sample data into the `product_reviews` table. This data includes reviews for various products such as laptops, phones, and tablets.

```sql
-- Insert sample data into `product_reviews` table
INSERT INTO product_reviews (customer_id, date, product, short_review, review) VALUES
(1, '2022-01-01', 'laptop', 'Great!', 'Great laptop, very fast and reliable.'),
(2, '2022-01-02', 'laptop', 'Good', 'Good laptop, but the battery life could be better.'),
(3, '2022-01-03', 'laptop', 'Worst ever', 'This is the worst laptop I have ever used.'),
(4, '2022-01-04', 'laptop', 'Not bad', 'Not bad, but the screen is a bit small.'),
(5, '2022-01-05', 'phone', 'Excellent', 'Excellent phone, great camera and battery life.'),
(6, '2022-01-06', 'phone', 'Decent', 'Decent phone, but the screen is not as good as I expected.'),
(7, '2022-01-07', 'phone', 'Poor', 'Poor phone, battery life is terrible and camera quality is not good.'),
(8, '2022-01-08', 'tablet', 'Awesome', 'Awesome tablet, very fast and responsive.'),
(9, '2022-01-09', 'tablet', 'Satisfactory', 'Satisfactory tablet, but the screen resolution could be better.'),
(10, '2022-01-10', 'tablet', 'Disappointing', 'Disappointing tablet, slow performance and battery drains quickly.')
;
```

Let's confirm that the sample product reviews have been inserted into the `product_reviews` table by running the following command:
```sql
SELECT * FROM product_reviews;
```

Output:
```bash
 customer_id |          date          | product | short_review  |                                review                                
-------------+------------------------+---------+---------------+----------------------------------------------------------------------
           1 | 2022-01-01 00:00:00+00 | laptop  | Great!        | Great laptop, very fast and reliable.
           2 | 2022-01-02 00:00:00+00 | laptop  | Good          | Good laptop, but the battery life could be better.
           3 | 2022-01-03 00:00:00+00 | laptop  | Worst ever    | This is the worst laptop I have ever used.
           4 | 2022-01-04 00:00:00+00 | laptop  | Not bad       | Not bad, but the screen is a bit small.
           5 | 2022-01-05 00:00:00+00 | phone   | Excellent     | Excellent phone, great camera and battery life.
           6 | 2022-01-06 00:00:00+00 | phone   | Decent        | Decent phone, but the screen is not as good as I expected.
           7 | 2022-01-07 00:00:00+00 | phone   | Poor          | Poor phone, battery life is terrible and camera quality is not good.
           8 | 2022-01-08 00:00:00+00 | tablet  | Awesome       | Awesome tablet, very fast and responsive.
           9 | 2022-01-09 00:00:00+00 | tablet  | Satisfactory  | Satisfactory tablet, but the screen resolution could be better.
          10 | 2022-01-10 00:00:00+00 | tablet  | Disappointing | Disappointing tablet, slow performance and battery drains quickly.
(10 rows)
```

## Creating the `product_reviews_classification` Table

Now that we have inserted sample product reviews into the `product_reviews` table, we will create a new table named `product_reviews_classification` to store the classification results of the product reviews. The `product_reviews_classification` table will include columns for customer ID and review type. The following SQL command creates a table named `product_reviews_classification` to store the classification results of customer product reviews. The table includes columns for customer ID and review type.

```sql
-- Create the `product_reviews_classification` table
CREATE TABLE product_reviews_classification (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    review_type TEXT                      -- The classification type of the review (e.g., Positive, Negative, Neutral)
)
;
```

## Classifying Product Reviews and Inserting into `product_reviews_classification` Table

Now that we have created the `product_reviews_classification` table, we will classify the product reviews into positive, negative, or neutral categories using the OpenAI API. We will use the `openai_chat_complete` function provided by the pgai extension to interact with the OpenAI API and classify the reviews. The following SQL script classifies product reviews into "positive," "negative," or "neutral" categories using the OpenAI model and inserts the results into the `product_reviews_classification` table.

```sql
-- Step 1: Format reviews with a structured template
WITH formatted_reviews AS (
    SELECT 
        customer_id,
        format(
            E'%s %s\nshort_review: %s\nreview: %s\n\t',
            short_review, review, short_review, review
        ) AS product_final_review
    FROM product_reviews
),

-- Step 2: Classify reviews using OpenAI and categorize the results
classified_reviews AS (
    SELECT
        customer_id,
        CASE
            WHEN result IN ('positive', 'negative', 'neutral') THEN result
            ELSE 'neutral'
        END AS review_type
    FROM (
        SELECT
            customer_id,
            openai_chat_complete(
                'gpt-4o',
                jsonb_build_array(
                    jsonb_build_object(
                        'role', 'system',
                        'content', 'You are an assistant that classifies product reviews into positive, negative, or neutral categories. You can only output one of these three categories: positive, negative, or neutral.'
                    ),
                    jsonb_build_object(
                        'role', 'user',
                        'content', 
                        concat(
                            E'Classify the following product review into positive, negative, or neutral categories. You cannot output anything except "positive", "negative", "neutral":\n\n',
                            string_agg(x.product_final_review, E'\n\n')
                        )
                    )
                )
            )->'choices'->0->'message'->>'content' AS result
        FROM formatted_reviews x
        GROUP BY customer_id
    ) subquery
)

-- Step 3: Insert classified reviews into the `product_reviews_classification` table
INSERT INTO product_reviews_classification (customer_id, review_type)
SELECT customer_id, review_type
FROM classified_reviews
;
```

Let's confirm that the product reviews have been classified and inserted into the `product_reviews_classification` table by running the following command:
```sql
SELECT * FROM product_reviews_classification;
```

Output:
```bash
 customer_id | review_type 
-------------+-------------
           4 | neutral
          10 | negative
           6 | neutral
           2 | neutral
           9 | neutral
           3 | negative
           5 | positive
           7 | negative
           1 | positive
           8 | positive
(10 rows)
```

## Joining the `product_reviews` and `product_reviews_classification` Tables

Now that we have classified the product reviews and inserted the results into the `product_reviews_classification` table, we can join the `product_reviews` and `product_reviews_classification` tables to view the classified reviews. The following SQL query joins the `product_reviews` and `product_reviews_classification` tables on the `customer_id` column and selects the customer ID, review, and review type.

```sql
-- Join the `product_reviews` and `product_reviews_classification` tables
SELECT 
    pr.customer_id,
    pr.review,
    prc.review_type
FROM
    product_reviews pr
JOIN
    product_reviews_classification prc
ON
    pr.customer_id = prc.customer_id;
```

Output:
```bash
 customer_id |                                review                                | review_type 
-------------+----------------------------------------------------------------------+-------------
           4 | Not bad, but the screen is a bit small.                              | neutral
          10 | Disappointing tablet, slow performance and battery drains quickly.   | negative
           6 | Decent phone, but the screen is not as good as I expected.           | neutral
           2 | Good laptop, but the battery life could be better.                   | neutral
           9 | Satisfactory tablet, but the screen resolution could be better.      | neutral
           3 | This is the worst laptop I have ever used.                           | negative
           5 | Excellent phone, great camera and battery life.                      | positive
           7 | Poor phone, battery life is terrible and camera quality is not good. | negative
           1 | Great laptop, very fast and reliable.                                | positive
           8 | Awesome tablet, very fast and responsive.                            | positive
(10 rows)
```

Great! We have successfully classified the product reviews into positive, negative, or neutral categories using the OpenAI API and inserted the results into the `product_reviews_classification` table. We then joined the `product_reviews` and `product_reviews_classification` tables to view the classified reviews.

# Data Classification via Embeddings using pgvector, pgai, and OpenAI API

In this section, we will use the pgvector extension to create embeddings for the product reviews and queries. We will then use the pgai extension to classify the product reviews based on the similarity between the review embeddings and query embeddings. We will use the OpenAI API to generate embeddings for the reviews and queries.

## Creating the `product_reviews_embedding` Table

Let's create a new table named `product_reviews_embedding` to store the embeddings of the product reviews. The `product_reviews_embedding` table will include columns for customer ID and embedding. 

Before we create the `product_reviews_embedding` table, we need to install the vectorscale extension. The vectorscale extension provides us with a fast and efficient implementation of indexing and searching on vector data types. You can install the vectorscale extension using the following command:

```sql
CREATE EXTENSION IF NOT EXISTS vectorscale;
```

Let's see all the extensions that are installed in the PostgreSQL database by running the following command:
```sql
\dx
```

Output:
```bash
 ai                  | 0.3.0   | public     | helper functions for ai workflows
 plpgsql             | 1.0     | pg_catalog | PL/pgSQL procedural language
 plpython3u          | 1.0     | pg_catalog | PL/Python3U untrusted procedural language
 timescaledb         | 2.15.3  | public     | Enables scalable inserts and complex queries for time-series data (Community Edition)
 timescaledb_toolkit | 1.18.0  | public     | Library of analytical hyperfunctions, time-series pipelining, and other SQL utilities
 vector              | 0.7.2   | public     | vector data type and ivfflat and hnsw access methods
 vectorscale         | 0.2.0   | public     | pgvectorscale:  Advanced indexing for vector data
(7 rows)
```

Now let's create the embedding table for the product reviews. The following SQL command creates the `product_reviews_embedding` table with a `customer_id` column and an `embedding` column of type `vector`.

```sql
-- Create the `product_reviews_embedding` table
CREATE TABLE product_reviews_embedding (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    embedding VECTOR(1536)               -- The vector type comes from the pgvector extension
);

-- Create an index on the `embedding` column using `diskann` for efficient vector search
CREATE INDEX product_reviews_embedding_idx ON product_reviews_embedding
USING diskann (embedding);
```

## Generating Embeddings for Product Reviews

Let's now generate embeddings for the product reviews using the OpenAI API. We will use the `openai_embed` function provided by the pgai extension to interact with the OpenAI API and generate embeddings for the reviews. The following SQL command inserts embeddings into the `product_reviews_embedding` table. It uses the `openai_embed` function to generate embeddings from the combined `short_review` and `review` fields of the `product_reviews` table.

```sql
-- Insert embeddings into the `product_reviews_embedding` table
INSERT INTO product_reviews_embedding (customer_id, embedding)
SELECT
    customer_id,
    openai_embed('text-embedding-3-small', format('short_review: %s review: %s', short_review, review)) AS embedding
FROM product_reviews;
```

## Creating the `query_embeddings` Table

Great! We have successfully generated embeddings for the product reviews and inserted them into the `product_reviews_embedding` table. Now to do a classification based on the similarity between the review embeddings and query embeddings, we will create a new table named `query_embeddings` to store the embeddings of the queries. The `query_embeddings` table will essentially have three queries: "which of these are positive reviews," "which of these are negative reviews," and "which of these are neutral reviews." The following SQL command creates a table named `query_embeddings` to store query texts and their corresponding embeddings.

```sql
-- Create the `query_embeddings` table
CREATE TABLE query_embeddings (
    id INT NOT NULL PRIMARY KEY,  -- Unique identifier for each query
    query TEXT,                   -- The query text
    embedding VECTOR(1536)        -- The embedding vector of 1536 dimensions
)
;
```

## Generating Embeddings for Queries

Now that we have created the `query_embeddings` table, we will generate embeddings for the queries using the OpenAI API. We will use the `openai_embed` function provided by the pgai extension to interact with the OpenAI API and generate embeddings for the queries. The following SQL command inserts embeddings into the `query_embeddings` table. It uses the `openai_embed` function to generate embeddings for the queries.

```sql
-- Insert example queries along with their embeddings into the `query_embeddings` table
INSERT INTO query_embeddings (id, query, embedding)
VALUES
(1, 'which of these are positive reviews?', openai_embed('text-embedding-3-small', 'which of these are positive reviews?')),
(2, 'which of these are negative reviews?', openai_embed('text-embedding-3-small', 'which of these are negative reviews?')),
(3, 'which of these are neutral reviews?', openai_embed('text-embedding-3-small', 'which of these are neutral reviews?'))
;
```

## Similarity Search based on the Query and Review Embeddings

Now that we have generated embeddings for the queries and we have the embeddings for the product reviews, we can do a similarity search based on the query and review embeddings. We will use the `<=>` operator provided by the pgvector extension to calculate the cosine distance between the query and review embeddings. The lower the cosine distance, the more similar the embeddings are. The following SQL query joins the `product_reviews`, `product_reviews_embedding`, `query_embeddings`, and `product_reviews_classification` tables to perform a similarity search based on the query and review embeddings. 

### Query 1: Which of these are positive reviews?

```sql
-- Retrieve the top 10 product reviews most similar to the query "which of these are neutral reviews?"
-- Include the similarity score in the results
SELECT 
    pr.customer_id,  
    pr.product, 
    pr.short_review, 
    pr.review,
    prc.review_type AS direct_classification,
    (pre.embedding <=> qe.embedding) AS cosine_distance -- Calculate similarity score
FROM product_reviews pr
JOIN product_reviews_embedding pre ON pr.customer_id = pre.customer_id
JOIN query_embeddings qe ON qe.id = 1 -- Using the embedding of the third query: "which of these are positive reviews?"
JOIN product_reviews_classification prc ON pr.customer_id = prc.customer_id
ORDER BY pre.embedding <=> qe.embedding -- Order by the similarity of embeddings
LIMIT 10; -- Limit the results to the top 10 most similar reviews
```

Output:
```bash
 customer_id | product | short_review  |                                review                                | direct_classification |  cosine_distance   
-------------+---------+---------------+----------------------------------------------------------------------+-----------------------+--------------------
           8 | tablet  | Awesome       | Awesome tablet, very fast and responsive.                            | positive              | 0.6251257397421806
           5 | phone   | Excellent     | Excellent phone, great camera and battery life.                      | positive              | 0.6430644669888423
          10 | tablet  | Disappointing | Disappointing tablet, slow performance and battery drains quickly.   | negative              |  0.646936325454978
           1 | laptop  | Great!        | Great laptop, very fast and reliable.                                | positive              | 0.6585465364348758
           9 | tablet  | Satisfactory  | Satisfactory tablet, but the screen resolution could be better.      | neutral               | 0.6596265422630088
           2 | laptop  | Good          | Good laptop, but the battery life could be better.                   | neutral               | 0.6633445915589848
           4 | laptop  | Not bad       | Not bad, but the screen is a bit small.                              | neutral               | 0.6682725252156714
           6 | phone   | Decent        | Decent phone, but the screen is not as good as I expected.           | neutral               | 0.6689849993284009
           7 | phone   | Poor          | Poor phone, battery life is terrible and camera quality is not good. | negative              | 0.6816295696761807
           3 | laptop  | Worst ever    | This is the worst laptop I have ever used.                           | negative              | 0.6978437332371223
(10 rows)
```

direct_classification column shows the classification of the review based on the OpenAI API as we did in the previous section. cosine_distance column shows the similarity score between the query and review embeddings derived in this section. The lower cosine_distance indicates higher similarity between the query and review embeddings.

### Query 2: Which of these are negative reviews?

```sql
-- Retrieve the top 10 product reviews most similar to the query "which of these are neutral reviews?"
-- Include the similarity score in the results
SELECT 
    pr.customer_id,  
    pr.product, 
    pr.short_review, 
    pr.review,
    prc.review_type AS direct_classification,
    (pre.embedding <=> qe.embedding) AS cosine_distance -- Calculate similarity score
FROM product_reviews pr
JOIN product_reviews_embedding pre ON pr.customer_id = pre.customer_id
JOIN query_embeddings qe ON qe.id = 2 -- Using the embedding of the third query: "which of these are negative reviews?"
JOIN product_reviews_classification prc ON pr.customer_id = prc.customer_id
ORDER BY pre.embedding <=> qe.embedding -- Order by the similarity of embeddings
LIMIT 10; -- Limit the results to the top 10 most similar reviews
```

Output:
```bash
 customer_id | product | short_review  |                                review                                | direct_classification |  cosine_distance   
-------------+---------+---------------+----------------------------------------------------------------------+-----------------------+--------------------
          10 | tablet  | Disappointing | Disappointing tablet, slow performance and battery drains quickly.   | negative              | 0.5711923113820644
           3 | laptop  | Worst ever    | This is the worst laptop I have ever used.                           | negative              | 0.5769471400066356
           7 | phone   | Poor          | Poor phone, battery life is terrible and camera quality is not good. | negative              | 0.5923415300947882
           4 | laptop  | Not bad       | Not bad, but the screen is a bit small.                              | neutral               | 0.6285385676782895
           6 | phone   | Decent        | Decent phone, but the screen is not as good as I expected.           | neutral               | 0.6600597602111159
           2 | laptop  | Good          | Good laptop, but the battery life could be better.                   | neutral               | 0.6831429506284876
           9 | tablet  | Satisfactory  | Satisfactory tablet, but the screen resolution could be better.      | neutral               | 0.6888680087170606
           8 | tablet  | Awesome       | Awesome tablet, very fast and responsive.                            | positive              | 0.7185021983238038
           5 | phone   | Excellent     | Excellent phone, great camera and battery life.                      | positive              |  0.733627996850848
           1 | laptop  | Great!        | Great laptop, very fast and reliable.                                | positive              | 0.7672426333201715
(10 rows)
```

### Query 3: Which of these are neutral reviews?

```sql
-- Retrieve the top 10 product reviews most similar to the query "which of these are neutral reviews?"
-- Include the similarity score in the results
SELECT 
    pr.customer_id,  
    pr.product, 
    pr.short_review, 
    pr.review,
    prc.review_type AS direct_classification,
    (pre.embedding <=> qe.embedding) AS cosine_distance -- Calculate similarity score
FROM product_reviews pr
JOIN product_reviews_embedding pre ON pr.customer_id = pre.customer_id
JOIN query_embeddings qe ON qe.id = 3 -- Using the embedding of the third query: "which of these are neutral reviews?"
JOIN product_reviews_classification prc ON pr.customer_id = prc.customer_id
ORDER BY pre.embedding <=> qe.embedding -- Order by the similarity of embeddings
LIMIT 10; -- Limit the results to the top 10 most similar reviews
```

Output:
```bash
 customer_id | product | short_review  |                                review                                | direct_classification |  cosine_distance   
-------------+---------+---------------+----------------------------------------------------------------------+-----------------------+--------------------
           4 | laptop  | Not bad       | Not bad, but the screen is a bit small.                              | neutral               | 0.6839096326935707
           6 | phone   | Decent        | Decent phone, but the screen is not as good as I expected.           | neutral               | 0.6915015533861715
           2 | laptop  | Good          | Good laptop, but the battery life could be better.                   | neutral               | 0.6979139509303607
          10 | tablet  | Disappointing | Disappointing tablet, slow performance and battery drains quickly.   | negative              | 0.6997992754221805
           9 | tablet  | Satisfactory  | Satisfactory tablet, but the screen resolution could be better.      | neutral               | 0.7004579990965659
           5 | phone   | Excellent     | Excellent phone, great camera and battery life.                      | positive              | 0.7169549802595381
           8 | tablet  | Awesome       | Awesome tablet, very fast and responsive.                            | positive              | 0.7172793020439518
           7 | phone   | Poor          | Poor phone, battery life is terrible and camera quality is not good. | negative              | 0.7295625532194889
           1 | laptop  | Great!        | Great laptop, very fast and reliable.                                | positive              | 0.7323201021766521
           3 | laptop  | Worst ever    | This is the worst laptop I have ever used.                           | negative              | 0.7347387987686617
(10 rows)
```

Great! We have successfully performed a similarity search based on the query and review embeddings. We also included the direct classification of the reviews based on the OpenAI API in the results. The cosine_distance column shows the similarity score (cosine distance) between the query and review embeddings. The lower the cosine_distance, the more similar the embeddings are.

## Conclusion
In this tutorial, we demonstrated how to perform automatic data classification using PostgreSQL, pgvector, OpenAI, and pgai. We used the pgai extension to interact with the OpenAI API and classify product reviews into positive, negative, or neutral categories. We also used the pgvector extension to generate embeddings for the product reviews and queries and performed a similarity search based on the embeddings. By combining the power of PostgreSQL, pgvector, OpenAI, and pgai, you can build an automated data classification system that can classify text data based on certain criteria. We encourage you to try building your own automated classification system using these tools and explore the possibilities of AI-powered data classification.

## References
- https://github.com/timescale/pgai?tab=readme-ov-file#use-a-pre-built-docker-container
- https://docs.timescale.com/self-hosted/latest/install/installation-docker/
- https://www.timescale.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows/
- https://www.timescale.com/blog/pgai-giving-postgresql-developers-ai-engineering-superpowers/
- https://www.timescale.com/blog/use-open-source-llms-in-postgresql-with-ollama-and-pgai/