## Installation and Setup
https://github.com/timescale/pgai?tab=readme-ov-file#use-a-pre-built-docker-container
https://docs.timescale.com/self-hosted/latest/install/installation-docker/
https://www.timescale.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows/

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

## Running the Docker Container
After pulling the pgai Docker image, you can run a Docker container with the pgai and pgvector extensions enabled. You can use the following command to run the container:
```bash
docker run -d --name timescaledb -p 5432:5432 -e POSTGRES_PASSWORD=password timescale/timescaledb-ha:pg16
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

## Data Classification
Data classification is the process of categorizing data into different classes or categories based on certain criteria. In this tutorial, we will use the pgai extension to classify product reviews into positive, negative, or neutral categories using the OpenAI API. We will be provided with list of product reviews and our goal is to classify each review into one of the three categories: positive, negative, or neutral.

### Creating the `product_reviews` Table
The following SQL command creates a table named `product_reviews` to store customer product reviews. The table includes columns for customer ID, date of the review, product name, a short review, and a detailed review.

```sql
-- Create the `product_reviews` table
CREATE TABLE product_reviews (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    date TIMESTAMPTZ,                     -- Timestamp with timezone for the review date
    product TEXT,                         -- Name of the product being reviewed
    short_review TEXT,                    -- A brief summary of the review
    review TEXT                           -- The detailed review text
);
```

Let's confirm that the `product_reviews` table has been created successfully by running the following command:
```sql
\dt
```

Output:
```bash
public | product_reviews | table | postgres
```

### Inserting Sample Product Reviews
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
  (10, '2022-01-10', 'tablet', 'Disappointing', 'Disappointing tablet, slow performance and battery drains quickly.');
```

Let's confirm that the sample product reviews have been inserted into the `product_reviews` table by running the following command:
```sql
SELECT * FROM product_reviews;
```

Output:
```bash
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
```

## Creating the `product_reviews_classification` Table

Now that we have inserted sample product reviews into the `product_reviews` table, we will create a new table named `product_reviews_classification` to store the classification results of the product reviews. The `product_reviews_classification` table will include columns for customer ID and review type. The following SQL command creates a table named `product_reviews_classification` to store the classification results of customer product reviews. The table includes columns for customer ID and review type.

```sql
-- Create the `product_reviews_classification` table
CREATE TABLE product_reviews_classification (
    customer_id INT NOT NULL PRIMARY KEY, -- Unique identifier for each customer
    review_type TEXT                      -- The classification type of the review (e.g., Positive, Negative, Neutral)
);
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
FROM classified_reviews;
```

Let's confirm that the product reviews have been classified and inserted into the `product_reviews_classification` table by running the following command:
```sql
SELECT * FROM product_reviews_classification;
```

Output:
```bash
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
```
